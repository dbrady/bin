class TmuxSettings
  ACIMA_DIR = File.expand_path("~/acima/devel")

  attr_reader :name, :folder, :command
  def initialize(name, folder, command=nil)
    @name = name
    @folder = File.join(ACIMA_DIR, folder)
    @command = command || 'bin/start'
  end
end
