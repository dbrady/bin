# `start` — a central app launcher

**Status:** approved 2026-07-29

## Problem

Teammates don't document how to start their apps, so every checkout accumulates
a hand-rolled `start` script. Fourteen of them exist across `~/acima/devel`,
they show up as untracked files in every `git status`, and they have begun to
speciate: `aperture` has `start`, `start1`, `start2`, and `start2.badmaybe`;
`merchant_portal` has `start-anycable` and `start-q`;
`application-management-client` exists in four checkouts of the same repo, each
with its own near-identical copy.

The rationale trapped in those scripts is worth as much as the commands. The
`aperture` starters carry an eight-line explanation of why the port must be a
`--server.port` program arg rather than a `SERVER_PORT` env var. That comment
must survive the migration, which constrains the storage format and the write
path (see *Writing*).

## Scope

`start` is a launcher, not a shell-scripting replacement. One command string per
service. Genuinely complicated startup logic belongs in a private script that
`start` invokes — e.g. `application-management-client`'s redis-flush +
dotenv-precondition + `pnpm start:dev` sequence becomes
`~/private-bin/start-amc`, and the YAML entry is just that path.

Launching several services at once is explicitly out of scope. `merchant_portal`
needing server + anycable + sidekiq means three tmux panes, which is how it is
run today anyway.

## Data file

`~/.config/start/start.yml`, a YAML **mapping** keyed by scope.

`~/.config` rather than `~/.local/share` because `start edit` makes this
explicitly a hand-edited config file; `XDG_DATA_HOME` is for state an
application manages on your behalf.

```yaml
# Gradle forks bootRun from the long-lived daemon's environment and does NOT
# forward client-side env vars, so a SERVER_PORT= prefix is silently dropped
# whenever an idle daemon with a different value is reused. --server.port is
# forwarded explicitly AND outranks env in Spring's precedence, so it wins.
github.com/acima-credit/aperture:
  default: server
  server:  ./gradlew :aperture-gateway:bootRun --args='--server.port=7777' "$@"
  server2: ./gradlew :aperture-gateway:bootRun --args='--server.port=7778' "$@"

github.com/acima-credit/merchant_portal:
  default:  server
  server:   bin/rails server -p 3000 "$@"
  anycable: bundle exec anycable --log-grpc
  q:        bundle exec sidekiq

/Users/davidbrady/acima/devel/review.merchant_portal:
  default: console          # resolves to a service defined at the repo level
  db:      psql review_merchant_portal_development
```

### Scope keys

**Repo keys** are normalized from `git remote get-url origin`: scheme and user
stripped, `:` after host normalized to `/`, trailing `.git` stripped,
lowercased. `git@github.com:acima-credit/merchant_portal.git` and
`https://github.com/acima-credit/merchant_portal` both become
`github.com/acima-credit/merchant_portal`. Normalization is what lets the four
`application-management-client` checkouts share one entry. If there is no
`origin`, fall back to the sole remote; if there are several and none is
`origin`, there is no repo key.

**Folder keys** are absolute paths: `git rev-parse --show-toplevel` when inside
a repo, otherwise `Dir.pwd`. Using the toplevel rather than the literal cwd is
what makes `start` work from `merchant_portal/app/models`, which is where you
actually are most of the time.

### Merge semantics

```ruby
services = repo_services.merge(folder_services)
```

Folder beats repo per key. Because `default` is just another key in that hash, a
folder can override the default while pointing at a service defined only at the
repo level. Consequence: `default` is reserved and cannot name a service.

## Launching

Always:

```ruby
Kernel.exec('bash', '-c', command, 'start', *ARGV)
```

A shell is required because command strings may contain `;`, `&&`, or
redirection. `Kernel.exec(string, *args)` cannot be used — Ruby only routes
through a shell when given exactly one argument, so appending args silently
switches it to direct-exec mode and the shell metacharacters become literal
argv entries.

`bash -c CMD NAME ARGS...` sets `$0` to `NAME` and puts `ARGS` in `$1..$n`.
**Extra args therefore reach the program only where the command string says
`"$@"`.** No auto-appending: appending `"$@"` to a command ending in `fi` or
`done` produces a shell syntax error, and guessing when it is safe is worse
than requiring the author to be explicit. If args are given to a service whose
command has no `$@`/`$1`/`$*`, warn to stderr and launch anyway.

Bash execs a single simple command directly rather than forking, so no wrapper
process lingers to intercept Ctrl-C for the common case.

### New helper: `DbradyCli#exec_command!`

Added to `lib/dbrady_cli/shell.rb`. Every existing start script hand-rolls
`echo -e '\033[36m...\033[0m'` before launching; this replaces that.

```ruby
# Log a command in cyan, then REPLACE this process with it. Never returns,
# except under --pretend, where it prints and returns nil.
def exec_command!(command, *args, argv0: File.basename($PROGRAM_NAME))
  puts "exec_command!: #{command.inspect} args=#{args.inspect}" if debug?
  puts command.cyan unless quiet?
  return nil if pretend?

  Kernel.exec('bash', '-c', command, argv0, *args)
end
```

## CLI

| Invocation | Behavior |
|---|---|
| `start` | Exactly one service defined → run it. Multiple with no `default` → picker. `default` present → run it. Nothing under either key → error naming both keys searched, plus a `start new` hint. |
| `start <svc>` | Run it. Unknown name errors and lists what is available. |
| `start -i` | Always the picker, even for a single service. |
| `start new [--repo\|--folder] [--default] <name> <cmd>` | Record a service. |
| `start edit` | `exec $EDITOR <file>` (fall back to `vi`). |

A lone service is unambiguously the default, so requiring a keystroke to
confirm it would be noise.

The picker is `~/bin/selecta`, fed `name<TAB>command` lines via `IO.popen`; the
name is split back off the selection. selecta exits 1 on Ctrl-C, which aborts
without launching.

### `new` scope default

`--repo` when `Dir.exist?('./.git')`, else `--folder`. Standing at the repo root
signals "this is a property of the app"; standing in a subdirectory or a plain
folder signals "this is a property of this checkout." `--repo` and `--folder`
conflict (Optimist `conflicts`), and `--repo` outside a repo is an error.

Known asymmetry: git worktrees and submodules have `.git` as a *file*, not a
directory, so they default to `--folder`. That is the desired answer for
`review.merchant_portal`, but it is a surprise worth documenting rather than
rediscovering.

`<cmd>` must be a single argument. More than one trailing token is an error
telling you to quote it, rather than silently re-joining and mangling quoting.

### Option parsing

`new-ruby-with-subcommands` as the template, but with **`stop_on_unknown`**
instead of `stop_on SUBCOMMANDS`. `stop_on` only halts at listed words, so
`start server --binding=0.0.0.0` would hand `--binding` to Optimist and abort.
`stop_on_unknown` halts at the first non-flag token, leaving both the service
name and its args untouched.

Consequences: global flags must precede the service name, and `new` and `edit`
are reserved words that cannot be service names.

## Writing (`start new`)

**Never parse-then-dump.** `YAML.load` followed by `YAML.dump` deletes every
comment in the file, including the aperture rationale — which would make
`start new` destroy the thing `start edit` exists to let you write.

Instead, line surgery on the shallow two-level structure:

- **Scope key absent:** append `\n<key>:\n  <name>: <cmd>\n` at EOF.
- **Scope key present:** scan forward to the last non-blank indented line of
  that block and insert after it.
- **`--default`:** rewrite an existing `  default:` line in place, or insert one
  as the block's first entry.

`YAML.safe_load` is used for *lookup only*, never as a step in writing.

Values are emitted double-quoted with `"` and `\` escaped, because commands
routinely contain `#`, `:`, and single quotes, all of which are hostile to bare
YAML scalars.

## Errors

Each of these gets a specific message rather than a backtrace:

- Config file does not exist — `start new` creates it (including the parent
  directory); every other path reports it and suggests `start new`.
- `--repo` outside a git repo, or in a repo with no usable remote.
- Unknown service name — print the merged service list for this location.
- Unparseable YAML — report the Psych problem line and suggest `start edit`.
- `$EDITOR` unset — fall back to `vi`.

## Testing

`~/bin` has no test framework today. This introduces `test/test_start.rb` using
minitest (available globally, 5.25.4 / 6.x), run with `ruby test/test_start.rb`.

The script is loaded rather than shelled out to:

```ruby
load File.expand_path('../start', __dir__)
```

The existing `Application.new.run if __FILE__ == $PROGRAM_NAME` guard keeps the
load side-effect-free.

Pure functions are unit-tested directly: remote-URL normalization, the
merge/precedence rule, `$@` detection, and the YAML line-surgery writer (fed a
fixture string, asserted on the resulting string — including that comments and
blank lines survive).

Integration coverage uses `--pretend`, which prints the resolved command and
does not exec, so the whole resolution path can be asserted without launching a
Rails server. Verification of the real migration: build the YAML from the
fourteen existing scripts, then from each of those directories confirm that
`start`, `start -p <svc>`, and an invocation from a subdirectory all resolve to
the command the old script ran.

## Migration

The fourteen existing scripts are transcribed into `start.yml` and then deleted
from their checkouts. `application-management-client`'s multi-step script moves
to a private bin directory first; its YAML entry invokes that path.
