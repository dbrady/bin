# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A personal collection of ~800 executable utility scripts (mostly Ruby and Bash) living in `~/bin`. There is no build system, no Gemfile, no package manager — scripts are standalone executables. Ruby version is managed via `.tool-versions` (ruby 3.3.0).

## Repository Layout

- **Root directory**: All executable scripts live here (not in subdirectories)
- **`lib/dbrady_cli.rb`**: Shared CLI framework mixin, loaded by most Ruby scripts
- **`lib/dbrady_cli/`**: Submodules — `core.rb`, `options.rb`, `shell.rb`, `git.rb`, `jira.rb`, `logging.rb`
- **`lib/tiny_table.rb`**: Table formatting utility
- **`db/`**: SQLite databases (e.g., `git-settings.db` for `git-rebasable`)
- **`figlet-fonts/`**, **`tabs/`**, **`tmuxinatrix/`**: Data/config directories

## Creating New Scripts

For Ruby scripts, copy `new-ruby` as the template. It has the full DbradyCli boilerplate, Optimist option parsing with standard flags, and comments documenting advanced Optimist usage. Put app code in `run!`.

For trivial tasks, a bash script is fine.

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

## Conventions

- Use `colorize` for user-facing output (cyan for commands, green for success, red for errors)
- Scripts that pipe output should detect `headless?` (non-TTY) and suppress color/decoration — `new-ruby` already handles this with `String.disable_colorization unless $stdout.tty?`
- The `quiet?` method returns true if `--quiet` is passed OR if stdout is not a TTY
