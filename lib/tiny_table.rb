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
    table = []

    if head
      table << separator
      table << "| " + head.zip(column_widths).map { |cell, width| cell.to_s.center(width) }.join(" | ") + " |"
    end

    table << separator

    table += rows.map do |row|
      if row == [:separator]
        separator
      else

        "| " + row.zip(column_widths).map do |cell, width|
          cell = cell.to_s
          nudge_for_ansi = cell.length - visible_length(cell)
          # TODO: dynamic ljust/center/rjust based on column's content
          cell.ljust(width + nudge_for_ansi)
        end.join(" | ") + " |"
      end
    end
    table << separator

    table
  end

  def separator
    @separator ||= "+" + column_widths.map { |width| "-" * (width + 2) }.join("+") + "+"
  end

  def calculate_column_widths
    column_widths = (head ? head : rows.first).map(&:length)
    rows.each do |row|
      row.each_with_index do |cell, i|
        column_widths[i] = [column_widths[i], visible_length(cell.to_s)].max
      end
    end
    column_widths
  end

  # Strips SGR color codes and OSC-8 hyperlink wrappers, which take no screen columns.
  def visible_length(cell)
    cell.gsub(/\e\[[0-9;]*m/, '').gsub(/\e\]8;[^\e\a]*(?:\e\\|\a)/, '').length
  end

  def column_widths
    @column_widths ||= calculate_column_widths
  end
end

# test / example
if __FILE__ == $0
  table = TinyTable.new(rows: [["Alice", 34], ["Bob", 56], ["Charlie", 12]], head: ["Name", "Age"])
  table.rows << ["D".white.on_red.bold, 54]
  puts table.to_s
end
