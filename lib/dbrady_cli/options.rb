# Monkeypatch to add type: :symbol / :symbols to Optimist
module Optimist
  # Add support for type: :symbol
  class SymbolOption < Option
    register_alias :symbol
    def as_type(val) ; val.to_sym ; end
    def type_format ; "=<s>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map { |pg| pg.map { |param| as_type(param) } }
    end
  end

  # Option class for handling multiple Symbols
  class SymbolArrayOption < SymbolOption
    register_alias :symbols
    def type_format ; "=<s+>" ; end
    def multi_arg? ; true ; end
  end
end

module DbradyCli
  module ClassMethods
    def opt_flags
      @opt_flags ||= [:debug, :quiet, :verbose, :pretend]
    end

    def opt_readers
      @opt_readers ||= []
    end

    # opt_flag :debug will create `def debug?; opts[:debug]; end`
    # opt_flag :a, :b, :c will create a?, b? and c?
    def opt_flag(*fields)
      Array(fields).each do |field|
        flag ||= "#{field}?"
        raise "opt_flag '#{flag}' must not have hyphens" if flag.to_s.include? '-'
        opt_flags << field
        define_method flag do
          opts[field.to_sym]
        end
      end
    end

    # Promote option to reader method, e.g. opt_reader(:host) will create `def host; opts[:host]; end`
    def opt_reader(*fields)
      Array(fields).each do |field|
        raise "opt_field '#{field}' must not have hyphens" if field.to_s.include? '-'
        opt_readers << field
        define_method field do
          opts[field.to_sym]
        end
      end
    end

    def ensure_rails_runner!
      return if defined? Rails

      # get the file path of the caller so we can pass it to rails runner.
      caller_file = caller_locations(1, 1).first.path

      # favor the spring binstub over bundler, because spring go fast.
      spring = File.join(Dir.pwd, "bin/rails")

      rails_command = File.exist?(spring) ? spring : "bundle exec rails"

      command = "#{rails_command} runner #{caller_file} #{ARGV.map(&:inspect).join(' ')} 2>/dev/null"

      # puts command.cyan
      status = system(command)
      exit status
    end
  end

  def opt_flags
    self.class.opt_flags
  end

  def opt_readers
    self.class.opt_readers
  end

  def dump_opts
    puts opts.sort.to_h.inspect
    puts "opt_flags: (#{opt_flags.size})"
    opt_flags.each do |flag|
      flag_method = "#{flag}?"
      puts "#{flag}: #{public_send(flag_method).inspect}"
    end
    puts "opt_readers: (#{opt_readers.size})"
    opt_readers.each do |reader|
      puts "#{reader}: #{public_send(reader).inspect}"
    end
  end
end
