# `start` Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `~/bin/start`, a central launcher that replaces the fourteen hand-rolled `./start` scripts scattered across `~/acima/devel`.

**Architecture:** One executable Ruby file, `~/bin/start`, containing four small classes with clean seams: `Scope` (locates the current repo/folder keys), `ServiceConfig` (pure merge and lookup over parsed YAML), `YamlWriter` (pure string→string line surgery), and `Application` (Optimist CLI glue). A new `exec_command!` helper lands in the shared `lib/dbrady_cli/shell.rb`. Everything except `Application` and `Scope.detect` is a pure function, unit-tested directly; the CLI is covered end-to-end through `--pretend` against throwaway git repos.

**Tech Stack:** Ruby 3.4.9, Optimist 3.2.1, colorize 1.1.0, minitest (globally installed), Psych (stdlib YAML), `~/bin/selecta` for interactive selection.

## Global Constraints

- Spec of record: `docs/superpowers/specs/2026-07-29-start-script-design.md`. Read it before starting.
- Single command string per service. `start` is a launcher, not a shell-scripting replacement.
- `~/bin` has no Gemfile and no bundler. Gems are installed globally; `require` them directly.
- Ruby scripts in this repo follow `~/bin/new-ruby` / `~/bin/new-ruby-with-subcommands`: `include DbradyCli`, Optimist options, and the four standard flags `--debug -d`, `--pretend -p`, `--quiet -q`, `--verbose -v`, with `opts[:quiet] = !opts[:verbose] if opts[:verbose_given]`.
- `lib/dbrady_cli` is private to `~/bin`. Never require it from anything outside this repo.
- Config path is `~/.config/start/start.yml`, overridable via the `START_CONFIG` environment variable. The override exists so integration tests never touch the real file.
- Never `YAML.load` then `YAML.dump` the config. Psych deletes every comment on a round-trip, and preserving comments is a hard requirement.
- Comments in code explain *why*, never *what*. No design justifications, no ticket references.
- New scripts get `chmod +x`.
- Tests run with `ruby test/<file>.rb` from `~/bin`. No Rakefile.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/dbrady_cli/shell.rb` (modify) | Add `exec_argv` (pure argv construction) and `exec_command!` (log in cyan, then `Kernel.exec`). |
| `start` (create, executable) | The CLI. Holds `Scope`, `ServiceConfig`, `YamlWriter`, `Application`. |
| `test/test_dbrady_cli_shell.rb` (create) | Unit tests for the two new shell helpers. |
| `test/test_start.rb` (create) | Unit tests for `Scope.normalize_remote`, `ServiceConfig`, `YamlWriter`. |
| `test/test_start_integration.rb` (create) | End-to-end tests: real subprocess, throwaway git repos, `START_CONFIG`, `--pretend`. |

`start` stays a single file because `~/bin`'s convention is one file per executable (`CLAUDE.md`: "Root directory: All executable scripts live here"), and `lib/` is reserved for the shared framework. The internal class boundaries carry the decomposition instead. Tests reach the classes with `load File.expand_path('../start', __dir__)`, which works because the file ends in the standard `Application.new.run if __FILE__ == $PROGRAM_NAME` guard.

---

### Task 1: `exec_command!` in the shared shell helpers

Every existing start script hand-rolls `echo -e '\033[36m...\033[0m'` before launching. This replaces that and gives `start` its launch primitive.

The launch must go through `bash -c` because command strings may contain `;`, `&&`, or redirection. `Kernel.exec(string, *args)` cannot be used: Ruby only routes through a shell when handed exactly one argument, so appending args silently switches it to direct-exec mode and the metacharacters become literal argv entries. `bash -c CMD NAME ARGS...` sets `$0` to `NAME` and puts `ARGS` in `$1..$n`.

`exec_argv` exists as a separate method purely so the argv construction is testable — `Kernel.exec` never returns, so it cannot be asserted on directly.

**Files:**
- Modify: `lib/dbrady_cli/shell.rb` (append inside `module DbradyCli`, after `get_command_output`)
- Test: `test/test_dbrady_cli_shell.rb`

**Interfaces:**
- Consumes: `DbradyCli#debug?`, `#quiet?`, `#pretend?` from `lib/dbrady_cli/core.rb`
- Produces:
  - `exec_argv(command, args = [], argv0: 'start') -> Array<String>`
  - `exec_command!(command, *args, argv0: File.basename($PROGRAM_NAME)) -> nil` (never returns unless `pretend?`)

- [ ] **Step 1: Write the failing tests**

Create `test/test_dbrady_cli_shell.rb`:

```ruby
# frozen_string_literal: true

require 'minitest/autorun'
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'dbrady_cli'

# Minimal host object: DbradyCli's flag predicates read from #opts.
class ShellHost
  include DbradyCli

  def initialize(**overrides)
    @opts = { debug: false, pretend: false, quiet: true, verbose: false }.merge(overrides)
  end
end

class TestExecArgv < Minitest::Test
  def setup
    @host = ShellHost.new
  end

  def test_wraps_the_command_in_bash_c
    assert_equal ['bash', '-c', 'bin/rails s', 'start'],
                 @host.exec_argv('bin/rails s', [], argv0: 'start')
  end

  def test_args_follow_argv0_so_bash_puts_them_in_positional_params
    assert_equal ['bash', '-c', 'bin/rails s "$@"', 'start', '-p', '3000'],
                 @host.exec_argv('bin/rails s "$@"', ['-p', '3000'], argv0: 'start')
  end

  def test_compound_commands_are_passed_through_untouched
    command = 'redis-cli flushall async; pnpm run start:dev'
    assert_equal ['bash', '-c', command, 'start'], @host.exec_argv(command, [], argv0: 'start')
  end
end

class TestExecCommand < Minitest::Test
  def test_pretend_returns_without_execing
    assert_nil ShellHost.new(pretend: true).exec_command!('exit 1')
  end

  def test_pretend_prints_the_command_even_when_quiet
    # quiet? is true whenever stdout is not a TTY, which is always true under
    # the test runner. In pretend mode the command line is the entire output of
    # the program, so it must print anyway or `start -p svc | cat` prints nothing.
    host = ShellHost.new(pretend: true, quiet: true)
    out, _err = capture_io { host.exec_command!('bin/rails s -p 3000') }
    assert_includes out, 'bin/rails s -p 3000'
  end

  def test_non_pretend_replaces_the_process
    # Kernel.exec never returns, so this is verified in a child process.
    script = <<~RUBY
      $LOAD_PATH.unshift(#{File.expand_path('../lib', __dir__).inspect})
      require 'dbrady_cli'
      class H; include DbradyCli
        def initialize = @opts = { debug: false, pretend: false, quiet: true, verbose: false }
      end
      H.new.exec_command!('echo EXECED')
      puts 'NOT REACHED'
    RUBY
    out = IO.popen(['ruby', '-e', script], &:read)
    assert_includes out, 'EXECED'
    refute_includes out, 'NOT REACHED'
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ~/bin && ruby test/test_dbrady_cli_shell.rb`
Expected: FAIL — `NoMethodError: undefined method 'exec_argv'`

- [ ] **Step 3: Write the implementation**

Append inside `module DbradyCli` in `lib/dbrady_cli/shell.rb`, after `get_command_output`:

```ruby
  # Build the argv for launching a command string through bash.
  #
  # A shell is required because command strings may contain `;`, `&&`, or
  # redirection, and Kernel.exec only routes through a shell when given
  # exactly one argument -- passing extra args silently switches it to
  # direct-exec mode, where the metacharacters become literal argv entries.
  # `bash -c CMD NAME ARGS...` sets $0 to NAME and puts ARGS in $1..$n, so
  # args reach the program only where the command string says "$@".
  #
  # Split out from exec_command! because Kernel.exec never returns and so
  # cannot be asserted on.
  def exec_argv(command, args = [], argv0: 'start')
    ['bash', '-c', command, argv0, *args]
  end

  # Log a command in cyan, then REPLACE this process with it. Never returns,
  # except under --pretend, where it prints and returns nil.
  def exec_command!(command, *args, argv0: File.basename($PROGRAM_NAME))
    argv = exec_argv(command, args, argv0: argv0)
    puts "exec_command!: #{argv.inspect}" if debug?

    # Print even when quiet? in pretend mode: quiet? is true for any non-TTY
    # stdout, and in pretend mode this line IS the program's output.
    puts command.cyan if pretend? || !quiet?
    return nil if pretend?

    Kernel.exec(*argv)
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ~/bin && ruby test/test_dbrady_cli_shell.rb`
Expected: PASS, 6 assertions, 0 failures

- [ ] **Step 5: Commit**

```bash
cd ~/bin
git add lib/dbrady_cli/shell.rb test/test_dbrady_cli_shell.rb
git commit -m "Add exec_command! to DbradyCli shell helpers

Every hand-rolled ./start script in ~/acima/devel echoes its command in
cyan before launching. exec_command! is that pattern, plus Kernel.exec so
the launcher does not linger as a parent process eating signals.

Launch goes through 'bash -c CMD start ARGS' rather than Kernel.exec(cmd,
*args): Ruby only uses a shell when exec gets exactly one argument, so
appending args would turn a compound command's ; and && into literal argv.

Introduces test/ to this repo -- minitest, run directly with ruby.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `Scope` — locating the current repo and folder keys

Repo-key normalization is what lets the four `application-management-client` checkouts share one config entry: `git@github.com:...` and `https://github.com/...` must land on the same string.

**Files:**
- Create: `start` (first content; not yet executable logic beyond these classes)
- Test: `test/test_start.rb`

**Interfaces:**
- Produces:
  - `Location = Struct.new(:folder_key, :repo_key)`
  - `Scope.normalize_remote(url) -> String | nil`
  - `Scope.folder_key(cwd = Dir.pwd) -> String`
  - `Scope.repo_key(cwd = Dir.pwd) -> String | nil`
  - `Scope.detect(cwd = Dir.pwd) -> Location`

- [ ] **Step 1: Write the failing tests**

Create `test/test_start.rb`:

```ruby
# frozen_string_literal: true

require 'minitest/autorun'

# `start` has no .rb extension, so it is loaded rather than required. The
# `Application.new.run if __FILE__ == $PROGRAM_NAME` guard at the bottom keeps
# this side-effect free.
load File.expand_path('../start', __dir__)

class TestNormalizeRemote < Minitest::Test
  def test_scp_style_ssh_url
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('git@github.com:acima-credit/merchant_portal.git')
  end

  def test_https_url_normalizes_to_the_same_key
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('https://github.com/acima-credit/merchant_portal')
  end

  def test_https_url_with_dot_git_suffix
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('https://github.com/acima-credit/merchant_portal.git')
  end

  def test_casing_is_normalized
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('git@GitHub.com:Acima-Credit/Merchant_Portal.git')
  end

  def test_ssh_scheme_with_port
    assert_equal 'github.com/acima-credit/aperture',
                 Scope.normalize_remote('ssh://git@github.com:22/acima-credit/aperture.git')
  end

  def test_trailing_slash_is_stripped
    assert_equal 'github.com/acima-credit/kipper',
                 Scope.normalize_remote('https://github.com/acima-credit/kipper/')
  end

  def test_blank_and_nil_have_no_key
    assert_nil Scope.normalize_remote(nil)
    assert_nil Scope.normalize_remote('')
    assert_nil Scope.normalize_remote('   ')
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ~/bin && ruby test/test_start.rb`
Expected: FAIL — `LoadError` (no such file `start`)

- [ ] **Step 3: Write the implementation**

Create `start`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# start - launch this project's dev server, or any other recorded service.
#
# Replaces the pile of hand-rolled ./start scripts that accumulate as untracked
# files in every checkout. Services live in ~/.config/start/start.yml, keyed
# either by normalized git remote (shared by every checkout of a repo) or by
# absolute folder path (this checkout only). Folder entries override repo
# entries key by key, so a review checkout can redefine one service and
# inherit the rest.

require 'colorize'
require 'optimist'
require 'shellwords'
require 'yaml'
$LOAD_PATH.unshift(File.expand_path('~/bin/lib'))
require 'dbrady_cli'
String.disable_colorization unless $stdout.tty?

Location = Struct.new(:folder_key, :repo_key)
Resolved = Struct.new(:name, :command)

# Works out which config keys apply to the current directory.
module Scope
  module_function

  # Collapse every spelling of a remote URL onto one key, so the four
  # application-management-client checkouts share a single config entry.
  def normalize_remote(url)
    str = url.to_s.strip
    return nil if str.empty?

    str = str.sub(%r{\A[a-z][a-z0-9+.\-]*://}i, '')  # scheme
    str = str.sub(/\A[^\/@]+@/, '')                  # user@
    str = str.sub(/:\d+(?=\/)/, '')                  # :port
    str = str.sub(/:(?=[^\/])/, '/')                 # scp-style host:path
    str = str.sub(/\.git\z/, '').sub(/\/+\z/, '')
    return nil if str.empty?

    # Downcasing assumes a hosted remote; a case-sensitive local-path remote
    # would be mangled, which does not occur in practice here.
    str.downcase
  end

  # The git toplevel rather than the literal cwd, so `start` works from
  # merchant_portal/app/models -- which is where you usually are.
  def folder_key(cwd = Dir.pwd)
    toplevel = `git -C #{cwd.shellescape} rev-parse --show-toplevel 2>/dev/null`.strip
    toplevel.empty? ? File.expand_path(cwd) : toplevel
  end

  def repo_key(cwd = Dir.pwd)
    url = `git -C #{cwd.shellescape} remote get-url origin 2>/dev/null`.strip
    if url.empty?
      remotes = `git -C #{cwd.shellescape} remote 2>/dev/null`.split
      url = `git -C #{cwd.shellescape} remote get-url #{remotes.first.shellescape} 2>/dev/null`.strip if remotes.size == 1
    end
    normalize_remote(url)
  end

  def detect(cwd = Dir.pwd)
    Location.new(folder_key(cwd), repo_key(cwd))
  end
end

# APPLICATION CLASS ADDED IN TASK 5
```

Make it executable: `chmod +x start`

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ~/bin && ruby test/test_start.rb`
Expected: PASS, 8 assertions, 0 failures

- [ ] **Step 5: Commit**

```bash
cd ~/bin
git add start test/test_start.rb
git commit -m "Add Scope: resolve a directory to repo and folder config keys

Normalizing remote URLs (scheme, user@, port, scp-style colon, .git, case)
is what lets the four application-management-client checkouts share one
config entry instead of four near-identical ones.

Folder keys use the git toplevel rather than the literal cwd so that
'start' works from a subdirectory, which is where you usually are.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `ServiceConfig` — merge and lookup

Pure logic over the already-parsed YAML hash. `default` lives in the same hash as the services, which is what lets a folder override the default while pointing at a service defined only at the repo level — and is why `default` is a reserved name.

**Files:**
- Modify: `start` (insert after `module Scope`)
- Test: `test/test_start.rb`

**Interfaces:**
- Consumes: `Location`, `Resolved` from Task 2
- Produces:
  - `ServiceConfig.new(data_hash)`
  - `#services_for(location) -> Hash` (includes `'default'`)
  - `#commands_for(location) -> Hash` (excludes `'default'`)
  - `#resolve(location, name = nil) -> Resolved | nil` — `nil` means "ambiguous, run the picker"
  - `ServiceConfig::NoServices`, `ServiceConfig::UnknownService` (with `#name`, `#available`)

- [ ] **Step 1: Write the failing tests**

Append to `test/test_start.rb`:

```ruby
class TestServiceConfig < Minitest::Test
  DATA = {
    'github.com/acima-credit/merchant_portal' => {
      'default' => 'server',
      'server' => 'bin/rails server -p 3000 "$@"',
      'q' => 'bundle exec sidekiq',
      'console' => 'bin/rails console'
    },
    '/Users/davidbrady/acima/devel/review.merchant_portal' => {
      'default' => 'console',
      'q' => 'RAILS_ENV=review bundle exec sidekiq'
    },
    '/Users/davidbrady/plain' => { 'only' => 'echo hi' },
    '/Users/davidbrady/two' => { 'a' => 'echo a', 'b' => 'echo b' }
  }.freeze

  def setup
    @config = ServiceConfig.new(DATA)
  end

  def repo_only
    Location.new('/nowhere', 'github.com/acima-credit/merchant_portal')
  end

  def review
    Location.new('/Users/davidbrady/acima/devel/review.merchant_portal',
                 'github.com/acima-credit/merchant_portal')
  end

  def test_repo_services_apply_when_the_folder_has_no_entry
    assert_equal 'bundle exec sidekiq', @config.resolve(repo_only, 'q').command
  end

  def test_folder_overrides_repo_for_the_same_service_name
    assert_equal 'RAILS_ENV=review bundle exec sidekiq', @config.resolve(review, 'q').command
  end

  def test_folder_inherits_services_it_does_not_redefine
    assert_equal 'bin/rails server -p 3000 "$@"', @config.resolve(review, 'server').command
  end

  def test_folder_default_may_point_at_a_repo_level_service
    resolved = @config.resolve(review)
    assert_equal 'console', resolved.name
    assert_equal 'bin/rails console', resolved.command
  end

  def test_repo_default_is_used_when_no_name_is_given
    assert_equal 'server', @config.resolve(repo_only).name
  end

  def test_default_is_not_itself_selectable_as_a_service
    refute_includes @config.commands_for(repo_only).keys, 'default'
  end

  def test_a_lone_service_is_the_default
    location = Location.new('/Users/davidbrady/plain', nil)
    assert_equal 'only', @config.resolve(location).name
  end

  def test_several_services_and_no_default_is_ambiguous
    location = Location.new('/Users/davidbrady/two', nil)
    assert_nil @config.resolve(location)
  end

  def test_unknown_service_reports_what_is_available
    error = assert_raises(ServiceConfig::UnknownService) { @config.resolve(repo_only, 'nope') }
    assert_equal 'nope', error.name
    assert_equal %w[server q console], error.available
  end

  def test_a_default_pointing_at_a_missing_service_is_an_unknown_service
    config = ServiceConfig.new('/x' => { 'default' => 'ghost', 'real' => 'echo hi' })
    assert_raises(ServiceConfig::UnknownService) { config.resolve(Location.new('/x', nil)) }
  end

  def test_no_services_anywhere_raises
    assert_raises(ServiceConfig::NoServices) { @config.resolve(Location.new('/unknown', nil)) }
  end

  def test_a_nil_repo_key_is_harmless
    config = ServiceConfig.new('/x' => { 'a' => 'echo a' })
    assert_equal 'echo a', config.resolve(Location.new('/x', nil), 'a').command
  end

  def test_empty_config_raises_no_services
    assert_raises(ServiceConfig::NoServices) do
      ServiceConfig.new(nil).resolve(Location.new('/x', 'y'))
    end
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ~/bin && ruby test/test_start.rb`
Expected: FAIL — `NameError: uninitialized constant ServiceConfig`

- [ ] **Step 3: Write the implementation**

Insert into `start`, after the `Scope` module and before the `# APPLICATION CLASS` marker:

```ruby
# Merge and lookup over the parsed config. Pure -- no I/O, no git.
class ServiceConfig
  class NoServices < StandardError; end

  class UnknownService < StandardError
    attr_reader :name, :available

    def initialize(name, available)
      @name = name
      @available = available
      super("unknown service #{name.inspect}")
    end
  end

  def initialize(data)
    @data = data || {}
  end

  # Folder beats repo, key by key. Because 'default' is just another key, a
  # folder can override the default while pointing at a repo-level service --
  # which is also why 'default' cannot name a service.
  def services_for(location)
    repo = @data[location.repo_key] || {}
    folder = @data[location.folder_key] || {}
    repo.merge(folder)
  end

  def commands_for(location)
    services_for(location).reject { |key, _| key == 'default' }
  end

  # Returns nil when the choice is ambiguous, meaning the caller should run
  # the picker.
  def resolve(location, name = nil)
    services = services_for(location)
    commands = services.reject { |key, _| key == 'default' }
    raise NoServices if commands.empty?

    chosen = name || services['default'] || (commands.size == 1 ? commands.keys.first : nil)
    return nil if chosen.nil?
    raise UnknownService.new(chosen, commands.keys) unless commands.key?(chosen)

    Resolved.new(chosen, commands[chosen])
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ~/bin && ruby test/test_start.rb`
Expected: PASS, 21 assertions, 0 failures

- [ ] **Step 5: Commit**

```bash
cd ~/bin
git add start test/test_start.rb
git commit -m "Add ServiceConfig: folder-over-repo service resolution

'default' is stored as an ordinary key alongside the services rather than
in a separate section. That is what lets a folder entry override the
default while pointing at a service defined only at the repo level, and it
is the reason 'default' is reserved and cannot name a service.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `YamlWriter` — comment-preserving line surgery

The single most important constraint in the spec. `YAML.load` + `YAML.dump` silently deletes every comment in the file, which would make `start new` destroy exactly what `start edit` exists to let you write — including aperture's eight-line explanation of why the port must be a `--server.port` program arg.

**Files:**
- Modify: `start` (insert after `ServiceConfig`)
- Test: `test/test_start.rb`

**Interfaces:**
- Produces: `YamlWriter.new(text).add(scope:, name:, command:, default: false) -> String`

- [ ] **Step 1: Write the failing tests**

Append to `test/test_start.rb`:

```ruby
class TestYamlWriter < Minitest::Test
  FIXTURE = <<~YAML
    # Gradle forks bootRun from the long-lived daemon's environment and does
    # NOT forward client-side env vars, so a SERVER_PORT= prefix is silently
    # dropped. --server.port is forwarded explicitly and wins.
    github.com/acima-credit/aperture:
      default: server
      server: "./gradlew :aperture-gateway:bootRun --args='--server.port=7777' \\"$@\\""

    github.com/acima-credit/kipper:
      server: "bin/rails s -p 3002"
  YAML

  def write(text, **kwargs)
    YamlWriter.new(text).add(**kwargs)
  end

  def test_appends_a_new_scope_block_at_eof
    result = write(FIXTURE, scope: 'github.com/acima-credit/global_customer',
                            name: 'server', command: 'bin/rails s -p 3008')
    assert_includes result, "github.com/acima-credit/global_customer:\n"
    assert_includes result, %(  server: "bin/rails s -p 3008"\n)
  end

  def test_comments_survive_a_write
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'anycable', command: 'anycable-go --port=3334')
    assert_includes result, '# Gradle forks bootRun'
    assert_includes result, '# dropped. --server.port is forwarded explicitly and wins.'
  end

  def test_inserts_into_an_existing_block_without_disturbing_neighbors
    result = write(FIXTURE, scope: 'github.com/acima-credit/aperture',
                            name: 'server2', command: './gradlew --args=7778')
    assert_includes result, %(  server2: "./gradlew --args=7778"\n)
    # The kipper block must still be intact and still separated by a blank line.
    assert_includes result, "\ngithub.com/acima-credit/kipper:\n  server:"
  end

  def test_insertion_lands_inside_the_target_block
    result = write(FIXTURE, scope: 'github.com/acima-credit/aperture',
                            name: 'server2', command: 'echo two')
    lines = result.lines.map(&:chomp)
    aperture = lines.index('github.com/acima-credit/aperture:')
    kipper = lines.index('github.com/acima-credit/kipper:')
    added = lines.index('  server2: "echo two"')
    assert aperture < added, 'new entry must come after its scope key'
    assert added < kipper, 'new entry must come before the next scope key'
  end

  def test_rewriting_an_existing_service_replaces_it_in_place
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'server', command: 'bin/rails s -p 4002')
    assert_includes result, %(  server: "bin/rails s -p 4002"\n)
    refute_includes result, 'bin/rails s -p 3002'
    assert_equal 1, result.scan(/^  server:/).length
  end

  def test_default_replaces_an_existing_default_line
    result = write(FIXTURE, scope: 'github.com/acima-credit/aperture',
                            name: 'server2', command: 'echo two', default: true)
    assert_includes result, "  default: server2\n"
    refute_includes result, "  default: server\n"
    assert_equal 1, result.scan(/^  default:/).length
  end

  def test_default_is_inserted_first_when_the_block_has_none
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'q', command: 'bundle exec sidekiq', default: true)
    lines = result.lines.map(&:chomp)
    kipper = lines.index('github.com/acima-credit/kipper:')
    assert_equal '  default: q', lines[kipper + 1]
  end

  def test_double_quotes_and_backslashes_are_escaped
    result = write('', scope: '/x', name: 'srv', command: 'bin/rails s "$@" \\ok')
    assert_includes result, %(  srv: "bin/rails s \\"$@\\" \\\\ok"\n)
    assert_equal 'bin/rails s "$@" \\ok', YAML.safe_load(result).dig('/x', 'srv')
  end

  def test_output_is_always_parseable_yaml
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'db', command: 'psql kipper_dev # not a comment: really')
    parsed = YAML.safe_load(result)
    assert_equal 'psql kipper_dev # not a comment: really',
                 parsed.dig('github.com/acima-credit/kipper', 'db')
    assert_equal 'server', parsed.dig('github.com/acima-credit/aperture', 'default')
  end

  def test_writing_to_an_empty_file
    result = write('', scope: '/x', name: 'srv', command: 'echo hi', default: true)
    assert_equal({ '/x' => { 'default' => 'srv', 'srv' => 'echo hi' } }, YAML.safe_load(result))
  end

  def test_a_file_without_a_trailing_newline_is_handled
    result = write("/a:\n  x: \"echo a\"", scope: '/b', name: 'y', command: 'echo b')
    assert_equal({ '/a' => { 'x' => 'echo a' } , '/b' => { 'y' => 'echo b' } }, YAML.safe_load(result))
  end

  def test_bad_service_names_are_rejected
    assert_raises(ArgumentError) { write('', scope: '/x', name: 'has space', command: 'echo') }
    assert_raises(ArgumentError) { write('', scope: '/x', name: '', command: 'echo') }
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ~/bin && ruby test/test_start.rb`
Expected: FAIL — `NameError: uninitialized constant YamlWriter`

- [ ] **Step 3: Write the implementation**

Insert into `start`, after `ServiceConfig`:

```ruby
# Rewrites the config by line surgery rather than a YAML.load/YAML.dump
# round-trip. Psych drops every comment on a round-trip, so a round-trip
# writer would make `start new` delete the rationale that `start edit` exists
# to let you write.
class YamlWriter
  NAME = /\A[\w.\-]+\z/

  def initialize(text)
    @lines = text.to_s.lines
  end

  def add(scope:, name:, command:, default: false)
    raise ArgumentError, "invalid service name #{name.inspect}" unless NAME.match?(name.to_s)

    index = scope_index(scope)
    if index
      upsert_entry(index, name, command)
      set_default(scope_index(scope), name) if default
    else
      append_block(scope, name, command, default)
    end
    to_s
  end

  def to_s
    @lines.join
  end

  private

  def scope_index(scope)
    pattern = /\A#{Regexp.escape(scope)}:\s*(#.*)?\z/
    @lines.index { |line| pattern.match?(line.chomp) }
  end

  # Indices of the block's entries. Trailing blank lines are excluded so that
  # insertions land inside the block rather than in the gap before the next one.
  def block_range(index)
    last = index
    ((index + 1)...@lines.length).each do |i|
      line = @lines[i]
      break unless line.strip.empty? || line.start_with?(' ', "\t")

      last = i unless line.strip.empty?
    end
    (index + 1)..last
  end

  def find_key(range, key)
    pattern = /\A\s+#{Regexp.escape(key)}:/
    range.find { |i| pattern.match?(@lines[i]) }
  end

  def upsert_entry(index, name, command)
    range = block_range(index)
    entry = "  #{name}: #{quote(command)}\n"
    existing = find_key(range, name)
    existing ? @lines[existing] = entry : @lines.insert(range.end + 1, entry)
  end

  def set_default(index, name)
    line = "  default: #{name}\n"
    existing = find_key(block_range(index), 'default')
    existing ? @lines[existing] = line : @lines.insert(index + 1, line)
  end

  def append_block(scope, name, command, default)
    unless @lines.empty?
      @lines[-1] = "#{@lines[-1]}\n" unless @lines[-1].end_with?("\n")
      @lines << "\n" unless @lines[-1].strip.empty?
    end
    @lines << "#{scope}:\n"
    @lines << "  default: #{name}\n" if default
    @lines << "  #{name}: #{quote(command)}\n"
  end

  # Always double-quote: commands routinely contain #, :, and single quotes,
  # all of which are hostile to bare YAML scalars.
  def quote(value)
    %("#{value.to_s.gsub(/[\\"]/) { |char| "\\#{char}" }}")
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ~/bin && ruby test/test_start.rb`
Expected: PASS, 0 failures

- [ ] **Step 5: Commit**

```bash
cd ~/bin
git add start test/test_start.rb
git commit -m "Add YamlWriter: update start.yml without eating comments

YAML.load followed by YAML.dump silently deletes every comment in the
file. Using it here would mean 'start new' destroys the prose that 'start
edit' exists to let you write -- notably aperture's explanation of why the
port must be a --server.port program arg rather than a SERVER_PORT env var.

So the writer never re-emits: it line-scans for the scope key and inserts,
replaces, or appends whole lines, leaving everything else byte-identical.
Values are always double-quoted because commands routinely contain #, :,
and single quotes.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `Application` — the CLI

**Files:**
- Modify: `start` (replace the `# APPLICATION CLASS ADDED IN TASK 5` marker)
- Test: `test/test_start_integration.rb`

**Interfaces:**
- Consumes: `Scope.detect`, `ServiceConfig`, `YamlWriter`, `Resolved`, `DbradyCli#exec_command!`
- Produces: the `start` executable's user-facing behavior

Option parsing uses **`stop_on_unknown`**, not `stop_on SUBCOMMANDS`. `stop_on` only halts at listed words, so `start server --binding=0.0.0.0` would hand `--binding` to the top-level Optimist and abort. `stop_on_unknown` halts at the first non-flag token, leaving the service name *and* its args untouched. Consequences: global flags must precede the service name, and `new`/`edit` are reserved words.

- [ ] **Step 1: Write the failing tests**

Create `test/test_start_integration.rb`:

```ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# End-to-end: real subprocess, real git repos, throwaway config. --pretend
# means no service is ever actually launched.
class StartIntegrationTest < Minitest::Test
  BIN = File.expand_path('../start', __dir__)

  def setup
    @tmp = Dir.mktmpdir('start-test')
    @config = File.join(@tmp, 'start.yml')
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def make_repo(name, remote: "git@github.com:acima-credit/#{name}.git")
    path = File.join(@tmp, name)
    FileUtils.mkdir_p(path)
    system('git', 'init', '-q', path, exception: true)
    system('git', '-C', path, 'remote', 'add', 'origin', remote, exception: true) if remote
    path
  end

  def start(*args, dir:)
    Open3.capture3({ 'START_CONFIG' => @config }, BIN, *args, chdir: dir)
  end

  def write_config(data)
    File.write(@config, data)
  end
end

class TestStartLaunching < StartIntegrationTest
  def test_bare_start_runs_the_default
    repo = make_repo('merchant_portal')
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        default: server
        server: "bin/rails server -p 3000"
        q: "bundle exec sidekiq"
    YAML
    out, _err, status = start('-p', dir: repo)
    assert status.success?, out
    assert_includes out, 'bin/rails server -p 3000'
  end

  def test_named_service_runs_that_service
    repo = make_repo('merchant_portal')
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        default: server
        server: "bin/rails server -p 3000"
        q: "bundle exec sidekiq"
    YAML
    out, _err, status = start('-p', 'q', dir: repo)
    assert status.success?, out
    assert_includes out, 'bundle exec sidekiq'
  end

  def test_works_from_a_subdirectory
    repo = make_repo('merchant_portal')
    sub = File.join(repo, 'app', 'models')
    FileUtils.mkdir_p(sub)
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        server: "bin/rails server -p 3000"
    YAML
    out, _err, status = start('-p', dir: sub)
    assert status.success?, out
    assert_includes out, 'bin/rails server -p 3000'
  end

  def test_a_second_checkout_of_the_same_repo_shares_the_entry
    make_repo('amc')
    other = make_repo('amc.old', remote: 'https://github.com/acima-credit/amc')
    write_config(<<~YAML)
      github.com/acima-credit/amc:
        dev: "pnpm run start:dev"
    YAML
    out, _err, status = start('-p', 'dev', dir: other)
    assert status.success?, out
    assert_includes out, 'pnpm run start:dev'
  end

  def test_folder_entry_overrides_the_repo_entry
    repo = make_repo('merchant_portal')
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        default: server
        server: "bin/rails server -p 3000"
        q: "bundle exec sidekiq"
      #{repo}:
        q: "RAILS_ENV=review bundle exec sidekiq"
    YAML
    out, _err, status = start('-p', 'q', dir: repo)
    assert status.success?, out
    assert_includes out, 'RAILS_ENV=review bundle exec sidekiq'
  end

  def test_extra_args_are_passed_through_where_the_command_says_dollar_at
    repo = make_repo('aperture')
    write_config(<<~YAML)
      github.com/acima-credit/aperture:
        server: "echo GRADLE \\"$@\\""
    YAML
    out, _err, status = start('server', '--server.port=7778', dir: repo)
    assert status.success?, out
    assert_includes out, 'GRADLE --server.port=7778'
  end

  def test_extra_args_without_dollar_at_warn_and_still_launch
    repo = make_repo('kipper')
    write_config(<<~YAML)
      github.com/acima-credit/kipper:
        server: "echo STARTED"
    YAML
    out, err, status = start('server', '--nope', dir: repo)
    assert status.success?, err
    assert_includes out, 'STARTED'
    assert_match(/\$@/, err)
  end

  def test_unknown_service_lists_what_is_available
    repo = make_repo('kipper')
    write_config(<<~YAML)
      github.com/acima-credit/kipper:
        server: "bin/rails s -p 3002"
        anycable: "anycable-go --port=3334"
    YAML
    _out, err, status = start('ghost', dir: repo)
    refute status.success?
    assert_includes err, 'ghost'
    assert_includes err, 'server'
    assert_includes err, 'anycable'
  end

  def test_no_services_names_both_keys_it_searched
    repo = make_repo('unconfigured')
    write_config("/somewhere/else:\n  x: \"echo x\"\n")
    _out, err, status = start(dir: repo)
    refute status.success?
    assert_includes err, repo
    assert_includes err, 'github.com/acima-credit/unconfigured'
    assert_includes err, 'start new'
  end

  def test_missing_config_file_is_reported_not_crashed
    repo = make_repo('kipper')
    _out, err, status = start(dir: repo)
    refute status.success?
    assert_includes err, 'start new'
  end

  def test_broken_yaml_reports_the_line_and_suggests_edit
    repo = make_repo('kipper')
    write_config("github.com/acima-credit/kipper:\n  server: \"unterminated\n   : :\n")
    _out, err, status = start(dir: repo)
    refute status.success?
    assert_includes err, 'start edit'
  end

  def test_a_non_git_folder_falls_back_to_the_folder_key
    plain = File.join(@tmp, 'plain')
    FileUtils.mkdir_p(plain)
    write_config("#{plain}:\n  srv: \"echo PLAIN\"\n")
    out, _err, status = start('-p', dir: plain)
    assert status.success?, out
    assert_includes out, 'echo PLAIN'
  end
end

class TestStartNew < StartIntegrationTest
  def test_new_at_a_repo_root_defaults_to_the_repo_scope
    repo = make_repo('merchant_portal')
    _out, err, status = start('new', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'bundle exec sidekiq', data.dig('github.com/acima-credit/merchant_portal', 'q')
  end

  def test_new_in_a_subdirectory_defaults_to_the_folder_scope
    repo = make_repo('merchant_portal')
    sub = File.join(repo, 'app')
    FileUtils.mkdir_p(sub)
    _out, err, status = start('new', 'q', 'bundle exec sidekiq', dir: sub)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'bundle exec sidekiq', data.dig(repo, 'q')
  end

  def test_new_folder_flag_forces_the_folder_scope_at_a_repo_root
    repo = make_repo('merchant_portal')
    _out, err, status = start('new', '--folder', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'bundle exec sidekiq', data.dig(repo, 'q')
  end

  def test_new_default_flag_records_the_default
    repo = make_repo('merchant_portal')
    start('new', 'server', 'bin/rails s', dir: repo)
    _out, err, status = start('new', '--default', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'q', data.dig('github.com/acima-credit/merchant_portal', 'default')
  end

  def test_new_creates_the_config_file_and_its_directory
    repo = make_repo('merchant_portal')
    @config = File.join(@tmp, 'nested', 'dir', 'start.yml')
    _out, err, status = start('new', 'server', 'bin/rails s', dir: repo)
    assert status.success?, err
    assert File.exist?(@config)
  end

  def test_new_then_start_round_trips
    repo = make_repo('kipper')
    start('new', 'server', 'bin/rails s -p 3002', dir: repo)
    out, _err, status = start('-p', dir: repo)
    assert status.success?, out
    assert_includes out, 'bin/rails s -p 3002'
  end

  def test_new_preserves_comments_in_the_existing_file
    repo = make_repo('kipper')
    write_config("# keep me\ngithub.com/acima-credit/kipper:\n  server: \"bin/rails s\"\n")
    start('new', 'q', 'bundle exec sidekiq', dir: repo)
    assert_includes File.read(@config), '# keep me'
  end

  def test_new_rejects_an_unquoted_multi_word_command
    repo = make_repo('kipper')
    _out, err, status = start('new', 'q', 'bundle', 'exec', 'sidekiq', dir: repo)
    refute status.success?
    assert_match(/quote/i, err)
  end

  def test_new_repo_flag_outside_a_repo_is_an_error
    plain = File.join(@tmp, 'plain')
    FileUtils.mkdir_p(plain)
    _out, err, status = start('new', '--repo', 'q', 'echo q', dir: plain)
    refute status.success?
    assert_match(/remote|repo/i, err)
  end

  def test_repo_and_folder_flags_conflict
    repo = make_repo('kipper')
    _out, err, status = start('new', '--repo', '--folder', 'q', 'echo q', dir: repo)
    refute status.success?
    assert_match(/conflict/i, err)
  end

  def test_new_pretend_does_not_write
    repo = make_repo('kipper')
    _out, _err, status = start('-p', 'new', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?
    refute File.exist?(@config)
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ~/bin && ruby test/test_start_integration.rb`
Expected: FAIL — every test errors, since `start` has no `Application` class and produces no output

- [ ] **Step 3: Write the implementation**

Replace the `# APPLICATION CLASS ADDED IN TASK 5` marker in `start` with:

```ruby
# CLI Application
class Application
  include DbradyCli

  SELECTA = File.expand_path('~/bin/selecta')
  DEFAULT_CONFIG = File.expand_path('~/.config/start/start.yml')

  # rubocop:disable Metrics/MethodLength
  def parse_options
    @opts = Optimist.options do
      banner <<~BANNER
        start - launch a service for this project

        Usage:
          start [options] [<service>] [args...]
          start [options] new [--repo|--folder] [--default] <service> '<command>'
          start [options] edit

        Services live in ~/.config/start/start.yml, keyed by git remote (shared
        by every checkout of a repo) or by absolute folder path (this checkout
        only). Folder entries override repo entries key by key.

        Extra args reach the program only where the command says "$@":
          server: bin/rails server -p 3000 "$@"

        With no service named: runs the recorded default, or the only service if
        there is just one, otherwise opens the picker.

        Options (must come BEFORE the service name):
      BANNER
      opt :interactive, 'Pick the service interactively', short: :i, default: false
      opt :debug, 'Print extra debug info', short: :d, default: false
      opt :pretend, 'Print commands but do not run them', short: :p, default: false
      opt :quiet, 'Run with minimal output', short: :q, default: false
      opt :verbose, 'Run with verbose output (overrides --quiet)', short: :v, default: false

      # stop_on_unknown, not stop_on SUBCOMMANDS: stop_on only halts at listed
      # words, so `start server --binding=0.0.0.0` would hand --binding to this
      # parser and abort. Halting at the first non-flag token leaves the service
      # name and its args alone.
      stop_on_unknown
    end
    opts[:quiet] = !opts[:verbose] if opts[:verbose_given]
    dump_opts if debug?
    @command = ARGV.shift
  end
  # rubocop:enable Metrics/MethodLength

  def run
    parse_options
    case @command
    when 'new'  then run_new
    when 'edit' then run_edit
    else run_start(@command)
    end
  end

  private

  def config_path
    @config_path ||= ENV.fetch('START_CONFIG', DEFAULT_CONFIG)
  end

  def load_data
    return {} unless File.exist?(config_path)

    YAML.safe_load(File.read(config_path)) || {}
  rescue Psych::SyntaxError => e
    abort "start: #{config_path} is not valid YAML (line #{e.line}): #{e.problem}\n" \
          '       fix it with: start edit'
  end

  def run_start(name)
    location = Scope.detect
    config = ServiceConfig.new(load_data)
    resolved = choose(config, location, name)
    abort 'start: nothing selected' if resolved.nil?

    warn_about_dropped_args(resolved)
    exec_command!(resolved.command, *ARGV, argv0: 'start')
  rescue ServiceConfig::NoServices
    abort no_services_message(location)
  rescue ServiceConfig::UnknownService => e
    abort "start: no service #{e.name.inspect} here. Available: #{e.available.join(', ')}"
  end

  def choose(config, location, name)
    return pick(config.commands_for(location)) if opts[:interactive] && name.nil?

    config.resolve(location, name) || pick(config.commands_for(location))
  end

  # Args reach the program only via "$@", so silently dropping them would be a
  # confusing no-op. Warn, but still launch: the service itself is what was asked for.
  def warn_about_dropped_args(resolved)
    return if ARGV.empty?
    return if resolved.command.match?(/\$[@*1-9]/)

    warn %(start: #{resolved.name.inspect} does not use "$@"; ignoring extra args: #{ARGV.join(' ')})
  end

  def no_services_message(location)
    <<~MSG.rstrip
      start: no services recorded for this location. Looked under:
        folder: #{location.folder_key}
        repo:   #{location.repo_key || '(no git remote)'}
      Record one with: start new <service> '<command>'
    MSG
  end

  # selecta takes its list on stdin and does all its UI on /dev/tty, so a pipe
  # for the list and a pipe for the answer leaves the terminal to selecta.
  def pick(commands)
    return nil if commands.empty?

    width = commands.keys.map(&:length).max
    lines = commands.map { |name, command| format("%-#{width}s  %s", name, command) }
    choice = IO.popen(SELECTA, 'r+') do |io|
      io.puts lines
      io.close_write
      io.read
    end
    return nil unless $CHILD_STATUS&.success?
    return nil if choice.to_s.strip.empty?

    name = choice.strip.split(/\s+/).first
    Resolved.new(name, commands[name])
  end

  def run_edit
    FileUtils.mkdir_p(File.dirname(config_path))
    File.write(config_path, '') unless File.exist?(config_path)
    editor = ENV['EDITOR'].to_s.empty? ? 'vi' : ENV['EDITOR']
    exec_command!("#{editor} #{config_path.shellescape}", argv0: 'start')
  end

  # rubocop:disable Metrics/AbcSize
  def run_new
    sub = Optimist.options do
      banner <<~BANNER
        start new - record a service for this location

        Usage:
          start new [--repo|--folder] [--default] <service> '<command>'

        Write "$@" in the command wherever extra args from `start <service> ...`
        should land. Quote the whole command as one argument.

        Options:
      BANNER
      opt :repo, 'Attach to the git remote (every checkout of this repo)', default: false
      opt :folder, 'Attach to this folder only', default: false
      opt :default, 'Make this the default service for the location', default: false
      conflicts :repo, :folder
    end

    name, *rest = ARGV
    Optimist.die 'give a service name and a command' if name.nil? || rest.empty?
    Optimist.die "quote the command as one argument (got #{rest.length})" if rest.length > 1

    scope = new_scope(sub)
    text = File.exist?(config_path) ? File.read(config_path) : ''
    updated = YamlWriter.new(text).add(scope: scope, name: name, command: rest.first,
                                       default: sub[:default])

    if pretend?
      puts updated
    else
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, updated)
    end
    puts "recorded #{name} under #{scope}".green unless quiet?
  rescue ArgumentError => e
    abort "start: #{e.message}"
  end
  # rubocop:enable Metrics/AbcSize

  # Standing at the repo root signals "this is a property of the app"; standing
  # in a subdirectory or a plain folder signals "this is a property of this
  # checkout". Note that worktrees and submodules have .git as a FILE, so they
  # fall to --folder, which is the wanted answer for review checkouts.
  def new_scope(sub)
    return require_repo_key if sub[:repo]
    return Scope.folder_key if sub[:folder]

    Dir.exist?('.git') ? require_repo_key : Scope.folder_key
  end

  def require_repo_key
    Scope.repo_key || abort('start: --repo needs a git repo with a usable remote here')
  end
end

Application.new.run if __FILE__ == $PROGRAM_NAME
```

Add `require 'English'` and `require 'fileutils'` to the requires at the top of `start` — `$CHILD_STATUS` comes from `English` (capitalized; `require 'english'` is a different, nonexistent file on case-sensitive filesystems), and `FileUtils.mkdir_p` from `fileutils`.

- [ ] **Step 4: Run all the tests to verify they pass**

Run: `cd ~/bin && ruby test/test_start.rb && ruby test/test_start_integration.rb && ruby test/test_dbrady_cli_shell.rb`
Expected: PASS across all three files, 0 failures, 0 errors

- [ ] **Step 5: Manually verify the picker, which cannot be tested headlessly**

Run:
```bash
cd ~/bin
export START_CONFIG=/tmp/start-manual.yml
printf '%s\n' '/tmp:' '  a: "echo AAA"' '  b: "echo BBB"' > "$START_CONFIG"
cd /tmp && ~/bin/start -p
```
Expected: selecta's interactive list appears with `a` and `b`; picking `b` prints `echo BBB`; Ctrl-C prints `start: nothing selected` and exits nonzero. Then `rm /tmp/start-manual.yml; unset START_CONFIG`.

- [ ] **Step 6: Commit**

```bash
cd ~/bin
git add start test/test_start_integration.rb
git commit -m "Add the start CLI: launch, new, edit, interactive picker

Uses Optimist's stop_on_unknown rather than stop_on SUBCOMMANDS. stop_on
only halts at listed words, so 'start server --binding=0.0.0.0' would hand
--binding to the top-level parser and abort; halting at the first non-flag
token leaves both the service name and its args untouched. The cost is that
global flags must precede the service name, and new/edit are reserved.

Extra args warn rather than error when the command has no \"\$@\": the
service itself is still what was asked for, but silently dropping the args
would look like a no-op.

START_CONFIG overrides the config path so integration tests never touch the
real ~/.config/start/start.yml.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Migrate the fourteen existing scripts

**Files:**
- Create: `~/.config/start/start.yml`
- Create: `~/acima/devel/application-management-client/private-bin/start-amc` (and the equivalent in the other AMC checkouts, if wanted)
- Delete: the fourteen `start*` scripts, only after verification

The `application-management-client` script is the one case the spec explicitly pushes out of scope: redis flush + two `.env.development` existence checks + `pnpm start:dev` is a script, not a command. It moves to a private bin directory and the config entry invokes that path.

- [ ] **Step 1: Write the config file**

Create `~/.config/start/start.yml`:

```yaml
# Gradle forks bootRun from the long-lived daemon's environment and does NOT
# forward client-side env vars, so a `SERVER_PORT=7777 ./gradlew` prefix is
# silently dropped whenever an idle daemon with a different SERVER_PORT is
# reused, and the app binds the wrong port. A --server.port program arg is
# forwarded explicitly by Gradle and outranks any env var in Spring's property
# precedence, so it always wins. Two servers because you always run a pair.
github.com/acima-credit/aperture:
  default: server1
  server1: "./gradlew :aperture-gateway:bootRun --args='--server.port=7777' \"$@\""
  server2: "./gradlew :aperture-gateway:bootRun --args='--server.port=7778' \"$@\""

github.com/acima-credit/merchant_portal:
  default: server
  server: "bin/rails server -p 3000 \"$@\""
  anycable: "bundle exec anycable --log-grpc"
  q: "bundle exec sidekiq"

github.com/acima-credit/kipper:
  default: server
  server: "bin/rails s -p 3002 \"$@\""
  anycable: "anycable-go --host=0.0.0.0 --port=3334 --debug --rpc_host=localhost:50051"

github.com/acima-credit/application_management_system:
  default: server
  server: "bin/rails s -p 3030 \"$@\""

github.com/acima-credit/global_customer:
  default: server
  server: "bin/rails s -p 3008 \"$@\""

# The AMC startup is a redis flush plus two .env.development preconditions plus
# the dev server, which is a script rather than a command. It lives in the
# checkout's private-bin/ and this just invokes it.
github.com/acima-credit/application-management-client:
  default: dev
  dev: "./private-bin/start-amc \"$@\""
```

Confirm each repo's actual normalized remote before trusting these keys:

```bash
for d in ~/acima/devel/{aperture,merchant_portal,kipper,application_management_system,global_customer,application-management-client}; do
  printf '%-70s %s\n' "$d" "$(git -C "$d" remote get-url origin 2>/dev/null)"
done
```

Fix any key in the YAML that does not match `Scope.normalize_remote` of the real URL. Note that `20250916.application_management_system` and the three extra `application-management-client` checkouts need no entries of their own — sharing the repo key is the point.

- [ ] **Step 2: Move the AMC startup script**

```bash
cd ~/acima/devel/application-management-client
mkdir -p private-bin
cp start private-bin/start-amc
chmod +x private-bin/start-amc
grep -q '^private-bin/$' .git/info/exclude || echo 'private-bin/' >> .git/info/exclude
```

Use `.git/info/exclude` rather than `.gitignore`: this is a personal directory in a shared repo, and `.gitignore` is checked in.

- [ ] **Step 3: Verify every migrated service resolves to the original command**

```bash
cd ~/acima/devel/aperture                       && ~/bin/start -p && ~/bin/start -p server2
cd ~/acima/devel/merchant_portal                && ~/bin/start -p && ~/bin/start -p q && ~/bin/start -p anycable
cd ~/acima/devel/kipper                         && ~/bin/start -p && ~/bin/start -p anycable
cd ~/acima/devel/application_management_system  && ~/bin/start -p
cd ~/acima/devel/20250916.application_management_system && ~/bin/start -p
cd ~/acima/devel/global_customer                && ~/bin/start -p
cd ~/acima/devel/application-management-client  && ~/bin/start -p
cd ~/acima/devel/application-management-client.old && ~/bin/start -p
cd ~/acima/devel/merchant_portal/app 2>/dev/null && ~/bin/start -p   # subdirectory
```

Expected: each prints the same command the corresponding old script ran. The two extra AMC/AMS checkouts must resolve via the shared repo key without entries of their own. Diff anything that does not match against the original script before proceeding.

- [ ] **Step 4: Verify arg passthrough and the failure paths**

```bash
cd ~/acima/devel/aperture && ~/bin/start -p server2 --debug-jvm   # arg reaches the command
cd ~/acima/devel/merchant_portal && ~/bin/start -p q --nope       # warns about "$@", still launches
cd /tmp && ~/bin/start                                            # names both keys, suggests start new
```

- [ ] **Step 5: Remove the old scripts**

Only after Steps 3 and 4 are clean. These are untracked files, so deletion is unrecoverable — list before removing:

```bash
ls -l ~/acima/devel/application-management-client.old/start \
      ~/acima/devel/20250916.application_management_system/start \
      ~/acima/devel/application_management_system/start \
      ~/acima/devel/global_customer/start \
      ~/acima/devel/application-management-client.newer-but-still-awful/start \
      ~/acima/devel/merchant_portal/start-anycable \
      ~/acima/devel/merchant_portal/start-q \
      ~/acima/devel/aperture/start1 \
      ~/acima/devel/aperture/start \
      ~/acima/devel/aperture/start2 \
      ~/acima/devel/aperture/start2.badmaybe \
      ~/acima/devel/application-management-client/start \
      ~/acima/devel/kipper/start \
      ~/acima/devel/kipper/start-anycable
```

Then `rm` that list. The AMC copy in `private-bin/start-amc` is the survivor.

- [ ] **Step 6: Document the script and commit**

Add `start` to the "Git Scripts"/key-scripts orientation in `~/bin/CLAUDE.md` under a short "Other Key Scripts" note, so a future session finds it instead of writing a new one.

```bash
cd ~/bin
git add CLAUDE.md
git commit -m "Document the start launcher in CLAUDE.md

Fourteen ad-hoc start scripts existed because nothing pointed at a central
one. Recording it here is what stops the next session from adding a
fifteenth.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

Spec coverage check against `2026-07-29-start-script-design.md`:

| Spec section | Task |
|---|---|
| Data file, `~/.config` path, `START_CONFIG` override | 5 |
| Repo key normalization | 2 |
| Folder key = git toplevel | 2 |
| Merge semantics, `default` reserved | 3 |
| `bash -c` launch, explicit `"$@"`, no auto-append | 1, 5 |
| `exec_command!` helper | 1 |
| CLI table (bare / named / `-i` / `new` / `edit`) | 5 |
| Picker via selecta | 5 (Step 5 manual, since it needs a TTY) |
| `new` scope default, worktree asymmetry | 5 |
| Single quoted `<cmd>` argument | 5 |
| `stop_on_unknown` | 5 |
| Line-surgery writes, comment preservation | 4 |
| Error messages (missing config, bad YAML, unknown service, no remote, no `$EDITOR`) | 5 |
| Testing approach | 1–5 |
| Migration | 6 |
