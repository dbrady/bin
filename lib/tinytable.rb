#!/usr/bin/env ruby
# TinyTable - cheap text table class that is ansi color aware. In a perfect world I'd submit a patch to Text::Table, but I need this now.

require "colorize"

# table = TinyTable.new
# table.head = ["Name", "Age"]
# table.rows = [["Alice", 34], ["Bob", 56]]
# table.rows << ["Charlie", 12]
# puts table.to_s

# =>
# +---------+-----+
# | Name    | Age |
# +---------+-----+
# | Alice   | 34  |
# | Bob     | 56  |
# | Charlie | 12  |
# +---------+-----+
class TinyTable
  attr_accessor :rows, :head

  def initialize(head: nil, rows: [])
    @rows = rows
    @head = head
  end

  def to_s
    column_widths = calculate_column_widths
    separator = "+" + column_widths.map { |width| "-" * (width + 2) }.join("+") + "+"

    [
      separator,
      "| " + head.zip(column_widths).map { |cell, width| cell.to_s.center(width) }.join(" | ") + " |",
      separator
    ] + rows.map do |row|
      "| " + row.zip(column_widths).map do |cell, width|
        cell = cell.to_s
        nudge_for_ansi = cell.length - cell.uncolorize.length
        # TODO: dynamic ljust/center/rjust based on column's content
        cell.ljust(width + nudge_for_ansi)
      end.join(" | ") + " |"
    end + [
      separator
    ]
  end

  def calculate_column_widths
    column_widths = head.map(&:length)
    rows.each do |row|
      row.each_with_index do |cell, i|
        column_widths[i] = [column_widths[i], cell.to_s.gsub(/\033.*?m/,'').length].max
      end
    end
    column_widths
  end

end

# test / example
if __FILE__ == $0
  table = TinyTable.new(rows: [["Alice", 34], ["Bob", 56], ["Charlie", 12]], head: ["Name", "Age"])
  table.rows << ["D".white.on_red.bold, 54]
  puts table.to_s
end
