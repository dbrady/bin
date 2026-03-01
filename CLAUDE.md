# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal collection of ~800 executable utility scripts (mostly Ruby and Bash) living in `~/bin`. There is no build system, no Gemfile, no package manager — scripts are standalone executables. Ruby version is managed via `.tool-versions` (ruby 3.3.0).

## Repository Layout

- **Root directory**: All executable scripts live here (not in subdirectories)
- **`lib/dbrady_cli.rb`**: Shared CLI framework mixin, loaded by most Ruby scripts
- **`lib/dbrady_cli/`**: Submodules — `core.rb`, `options.rb`, `shell.rb`, `git.rb`, `jira.rb`, `logging.rb`
- **`lib/tiny_table.rb`**: Table formatting utility
- **`db/`**: SQLite databases (`git-settings.db`) with tables: `slorks` (JIRA tickets), `parent_branches`, `branch_history`, `pr_history`, `durations`. Schema in `db/schema-git-settings.sql`
- **`figlet-fonts/`**, **`tabs/`**, **`tmuxinatrix/`**: Data/config directories

## No Tests or CI

There is no test suite, no CI pipeline, no linter configuration, and no Makefile/Rakefile. Do not look for or try to run tests. Validate scripts manually or with `--pretend` / `--help`.

## Creating New Scripts

For Ruby scripts, copy `new-ruby` as the template: `cp new-ruby my-script && chmod +x my-script`. Replace `{{SCRIPT}}` with the script name, remove the `NOCOMMIT` markers, write a description in the banner, and put app code in `run!`. Remove the `Optimist.educate` line if the script takes no positional args.

Very small bash scripts are acceptable for trivial wrappers, but they must echo the command they're about to run in cyan so the user learns what's happening under the hood:

```bash
#!/bin/bash
echo -e "\033[36m<command here>\033[0m"
<command here>
```

Make all new scripts executable (`chmod +x`).

## DbradyCli Framework

The `DbradyCli` module (included via `include DbradyCli`) provides:

- **Standard flags**: `debug?`, `quiet?`, `verbose?`, `pretend?` — all scripts should support these via Optimist options
- **`opt_flag`/`opt_reader`** class methods: Declare custom boolean flags and option accessors
- **Command execution**: `run_command!` (raises on failure), `run_command` (returns status), `get_command_output`, `get_command_output_lines` — all respect `pretend?` mode and colorize output
- **Git helpers**: `git_current_branch`, `git_main_branch`, `git_parent_branch`, `git_files_changed`, `git_isclean`, etc. (these shell out to other scripts in this repo like `git current-branch`)
- **OS detection**: `osx?`, `linux?`
- **`ensure_rails_runner!`**: Class method that re-execs the script under `rails runner` if Rails isn't loaded
- **Optimist extensions**: `type: :symbol` and `type: :symbols` added via monkeypatch in `options.rb`

When `pretend?` is true, `run_command`/`run_command!` print commands in cyan but don't execute them. Use `force: true` to run even in pretend mode (for read-only commands like `git isclean`).

## Git Scripts

85+ scripts prefixed with `git-` extend Git as subcommands (e.g., `git-current-branch` becomes `git current-branch`). Many are used internally by DbradyCli and by each other. Key ones:

- `git-current-branch`, `git-main-branch`, `git-parent-branch` — branch detection
- `git-files-changed` — list changed files vs parent branch
- `git-rebasable` — SQLite-backed branch configuration flags
- `git-get-pr`, `git-get-pr-id` — GitHub PR lookup via `gh` CLI

## Key Ruby Gems (installed globally, no Gemfile)

- `colorize` — ANSI color output (`.cyan`, `.green`, `.red`, etc.)
- `optimist` — CLI option parsing
- `extralite` — SQLite access (used by `git-rebasable`)
- `pg` — PostgreSQL access (used by migration-checking scripts)
- `debug` — Ruby debugger

## Script Composition

Scripts frequently shell out to other scripts in this repo. For example, `git_current_branch` in DbradyCli calls `git current-branch` (which is `git-current-branch` in this repo). This means changes to foundational scripts like `git-current-branch`, `git-main-branch`, or `git-parent-branch` can affect many other scripts.

## Conventions

- **`colorize` is the standard** for ANSI color in Ruby — alternatives were tried and rejected. Use cyan for commands, green for success, red for errors.
- Scripts that pipe output should detect `headless?` (non-TTY) and suppress color/decoration — `new-ruby` already handles this with `String.disable_colorization unless $stdout.tty?`
- The `quiet?` method returns true if `--quiet` is passed OR if stdout is not a TTY
- **Hyphens for script names**, not underscores (e.g., `git-new-branch`, not `git_new_branch`)
- **`extralite`** is the standard for SQLite access (not `sqlite3` gem, not Sequel ORM)

## History and Archaeology

This repo spans **17 years** (Jan 2009 – present, ~2,340 commits). It has accumulated scripts across multiple employers and eras. Understanding the layers helps explain why the codebase is inconsistent.

### Eras

1. **Founding (2009)**: 37 initial scripts — bash, ruby, perl. Option parsing via **Trollop** gem. First `git-*` scripts (`git-currentbranch`, `git-pooll`).
2. **Dormant years (2010–2015)**: ~20 commits/year. Sporadic additions. `colorize` first appears 2014. RSpec focus scripts (`rf`, `rg`) added 2015.
3. **Figlet eruption (Oct 2016)**: 89 commits in one month importing 400+ figlet fonts. Created `figlet-banner`/`rubanner`.
4. **CoverMyMeds era (2017–2020)**: Philips Hue smart-light scripts for CI status (all since deleted). `gh` renamed to `git-home` when GitHub released their `gh` CLI (2020).
5. **Acceleration (2021)**: 218 commits, 94 new scripts. `git-isclean`, `git-main-branch`, `git-new-branch` established. `git-currentbranch` renamed to `git-current-branch` (hyphen standardization). Trollop fully replaced by **Optimist**.
6. **Snowflake/Acima explosion (2022–2023)**: Peak era — 957 commits across 2 years. ~185 Snowflake migration commits produced dozens of `snow-*` and `ds-*` scripts (mostly obsolete now). **DbradyCli created** (Nov 2023). **`new-ruby` template created** (Nov 2023). `extralite` chosen over `sqlite3` gem. `slorks` ticket-tracking system born.
7. **Maturation (2024)**: DbradyCli gains `opt_flag`, git helpers. Slorks goes database-backed. TinyTable created. Sequel ORM tried then abandoned for raw extralite.
8. **Current era (2025–present)**: `lib/` directory created, DbradyCli refactored into submodules (Feb 2026). `git-rebasable` ecosystem. Gradual migration of older scripts to DbradyCli. CLAUDE.md added.

### What This Means in Practice

**Option parsing is fragmented** — the single biggest inconsistency:
- ~74 scripts use DbradyCli (modern, post-Nov 2023)
- ~123 scripts use `require 'optimist'` directly (no DbradyCli wrapper)
- ~4 scripts use `OptionParser`
- ~190 Ruby scripts have no option parsing at all (raw `ARGV`)

**Naming is inconsistent**: Older scripts use underscores (`set_current_project`), newer ones use hyphens (`git-new-branch`). Modern convention is hyphens.

**Color/TTY handling varies**: Modern scripts (via `new-ruby`) suppress color for pipes. Older scripts may not, or may not use color at all.

**Dead weight from past employers**: `snow-*` and `ds-*` scripts from a 2022–2023 Snowflake migration are obsolete and will be moved to a historical branch and pruned. Scattered scripts from CoverMyMeds, KPMG eras remain. Some scripts have overlapping purposes (multiple branch navigators, multiple RSpec runners, multiple process killers like `diespringdie`/`diechromedie`).

**Database layer shifted**: Sequel ORM was tried (2024) then dropped back to raw extralite/sqlite3 (2025). Current standard is raw `extralite` with `db/git-settings.db`.

### Refactoring Direction

A large-scale migration to current standards is planned. When touching old scripts:
- **Nontrivial changes**: Upgrade to the `new-ruby` pattern (DbradyCli, Optimist, `run!` method, colorize, headless detection). This is the preferred direction.
- **Simple one-line fixes**: Leave the existing style alone.
- **Anything beyond a trivial bash wrapper**: Should be Ruby with DbradyCli, not bash.
