class TmuxSettings
  ACIMA_DIR = File.expand_path("~/acima/devel")

  attr_reader :name, :folder, :commands
  def initialize(name:, folder:, commands: nil)
    @name = name
    @folder = File.join(ACIMA_DIR, folder)
    @commands = commands || []
  end
end
