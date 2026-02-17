module DbradyCli
  attr_reader :opts

  # Autoload class methods
  def self.included(including_module)
    including_module.extend ClassMethods
  end

  # opt_flag :debug, :quiet, :verbose, :pretend
  def debug?
    opts[:debug]
  end

  def headless?
    !$stdout.tty?
  end

  def quiet?
    opts[:quiet] || headless?
  end

  def verbose?
    opts[:verbose]
  end

  def pretend?
    opts[:pretend]
  end
end
