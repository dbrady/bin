module DbradyCli
  # Log a command to the console, then run it (unless --pretend), and raise an
  # exception if fails.
  # if force=true, run the command even if we're in pretend mode (use this
  # for commands that are not dangerous, like git isclean)
  def run_command!(command, force: false, env: {})
    puts "run_command!: #{command.inspect}" if debug?
    puts command.cyan unless quiet?

    success = if force
                system env, command
              else
                pretend? || system(env, command)
              end

    raise "run_command! failed running #{command.inspect}" unless success
    success
  end

  # Log and run a command (unless --pretend), and return its exit status.
  # if force=true, run the command even if we're in pretend mode (use this
  # for commands that are not dangerous, like git isclean)
  def run_command(command, force: false, quiet: false, env: {})
    puts "run_command: #{command.inspect} (force: #{force.inspect}, pretend: #{pretend?.inspect})" if debug?
    command_pieces = env.map {|pair| pair.join('=')} + [command]
    command_text = command_pieces.compact * ' '
    puts command_text.cyan unless (quiet || quiet?)

    success = if force
      system env, command
    else
      pretend? || system(env, command)
    end
    puts "run_command failed running #{command.inspect}".yellow if debug? && !success
    success
  end

  def get_command_output_lines(command, quiet: false)
    get_command_output(command, quiet:).each_line.map(&:rstrip).to_a
  end

  # run a command and get its output as a single string (rstripping last line)
  def get_command_output(command, quiet: false)
    puts command.cyan unless (quiet || quiet?)
    if pretend?
      ""
    else
      `#{command}`.rstrip
    end
  end

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

  def osx?
    `uname -s`.strip == 'Darwin'
  end

  def linux?
    # I mean technically also Windows/WSL but lol who even uses that
    !osx?
  end
end
