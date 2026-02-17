module DbradyCli
  # Debug logging prints - no timestamp, always to $stdout
  # color: nil will suppress color
  def log(message="", color: [:cyan, :normal])
    message = message.colorize(color) if color

    puts message
  end
end
