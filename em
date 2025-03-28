#!/usr/bin/env ruby
# em - emacs-open - Send open-file keychords to emacs in another tmux window
require "colorize"
require "optimist"
require_relative "lib/dbrady_cli"
String.disable_colorization unless $stdout.tty?

class Application
  include DbradyCli

  opt_flag :force, :absolute

  def run
    @opts = Optimist.options do
      opt :force, "Force open even if file does not exist", default: false
      opt :session, "Name of session emacs is running in", type: :string, default: "work"
      opt :window, "Window number emacs is running in", type: :integer, default: 1
      opt :absolute, "Path is absolute from root (not relative to cwd)", default: false

      opt :debug, "Print extra debug info", default: false
      opt :pretend, "Print commands but do not run them", default: false
      opt :verbose, "Run with verbose output (overrides --quiet)", default: false
      opt :quiet, "Run with minimal output", default: false
    end
    opts[:quiet] = !opts[:verbose] if opts[:verbose_given]
    puts opts.inspect if opts[:debug]

    path = absolute? ? ARGV.first : File.join(Dir.pwd, ARGV.first)

    tmux_already_running = run_command "tmux list-sessions | grep -E '^#{opts[:session]}: [[:digit:]]+ windows '"
    # TODO: Use tmux list-windows -a | grep "emacs" to find which session has a
    # window named "emacs". Finding the active process in a window is harder,
    # but window name is easy, and I always name work:1 "emacs" anyway.
    #
    # This changes the logic a bit, instead of "is tmux running" I want session,
    # window = where_is_tmux_running_emacs, and possibly with a check for "is
    # there ONLY one emacs window running".

    if tmux_already_running
      puts "Opening #{path} with emacs in tmux session '#{opts[:session]}:#{opts[:window]}'..."
    else
      puts "Could not find a tmux session named '#{opts[:session]}'. These are the running tmuxen:"
      puts get_command_output_lines "tmux list-sessions"
      exit -1
    end
    puts "Is tmux already running a session named '#{opts[:session]}? #{tmux_already_running.inspect}"

    path, line = path.split(/:/)

    if force? || File.exist?(path)
      # TODO: git-new-branch duplicates this code. Refactor this to emacs-send?
      tmux_command = "tmux send-keys -t#{opts[:session]}:#{opts[:window]}"
      run_command "#{tmux_command} C-x C-f C-a C-k #{path} C-m"
      run_command "#{tmux_command} M-x goto-line C-m #{line} C-m M-x recenter-top-bottom C-m" if line
    else
      puts "File does not exist: #{path}"
      puts "Please fix the path or rerun with --force if you want to create the file"
    end
  end
end


if __FILE__ == $0
  Application.new.run
end
#!/bin/bash
