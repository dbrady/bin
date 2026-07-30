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
    # capture_io, not a bare call: exec_command! still puts the command
    # (that's the whole point of --pretend), and without capturing it that
    # cyan "exit 1" line leaks into the test runner's own output.
    out, _err = capture_io { assert_nil ShellHost.new(pretend: true).exec_command!('exit 1') }
    assert_includes out, 'exit 1'
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
