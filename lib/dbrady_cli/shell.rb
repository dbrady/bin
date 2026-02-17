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

    if force
      system env, command
    else
      pretend? || system(env, command)
    end
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

  def osx?
    `uname -s`.strip == 'Darwin'
  end

  def linux?
    # I mean technically also Windows/WSL but lol who even uses that
    !osx?
  end
end
