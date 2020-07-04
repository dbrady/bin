#!/usr/bin/env ruby
require 'optimist'

opts = Optimist.options do
  version "plot v 1.0.0 (C) 2010 David Brady"
  banner(<<EOS
plot - Use Gnuplot to plot a prepared datafile.

Copyright (C) David Brady. Released under the MIT license.

Overview:

    Gnuplot has a lot of options and switches. If you are reviewing
  and comparing frequent re-runs of data, you will find yourself using
  and reusing the same options over and over. You could put these
  commands into a batch or shell script. If you find yourself
  exploring data representations, however, this script will change
  frequently, and if you find yourself working with multiple distinct
  representations of data, you will find yourself maintaining
  different types of scripts. Enter the plot command.

    Plot lets you put scripting directives directly into the header of
  the datafile, so that when you change the data you are emitting, you
  simply change the information in the header as well. Plot can then
  read and act on these directives and create the full command to be
  sent to gnuplot.

    Plot assumes that your data is organized in tab-separated columns
  and that the first column identifies the x axis while all subsequent
  columns identify y axis plots.

Header Directives:

    Header directives are lines of text of the format

    # <name>: <value>

    At present, there are only two: LEGEND and COMMAND. Plot stops
  looking for header directives as soon as it sees a line that does
  not begin with #, so take care not to include blank lines.

    # LEGEND: <x_axis_title>; <column_title1>[; <column_title2> ...]

    Gives labels to the columns to be plotted in the file.

    # COMMAND: <command>

    Writes a command directive to gnuplot. Example: "# COMMAND: set
  log y". The command directive can appear any number of times, and
  you can include multiple commands on a single line by separating the
  commands with semicolons. NOTE: If COMMAND contains a set xlabel
  command, the first label in the legend (the x axis label) will be
  ignored. In other words, COMMAND trumps LEGEND if you explicitly
  order it to be so.

Plot Commands:

    You can pass arbitrary commands to the plot script using the
  --command switch; the argument should be a single string. Multiple
  commands can be added by separating them with semicolons. The same x
  axis label override statement is true here as well.

Extra Plots:

    You can add arbitrary plot lines to the output using the --add
  switch; you can reference other columns by number with a dollar
  sign. Separate multiple plots with semicolons. Example:

    plot datafile.dat --add 'sin($1); log($4-$3) title \"log diff\"'

    The title is optional. Currently, added plots MUST reference
  discrete columns in the data; you cannot reference the x axis except
  as $1.
EOS
         )
  opt :xrange, "XRange set the xrange to show", :type => :string, :default => nil
  opt :only, "Only show columns (eg: -o 'foo; bar')", :type => :string, :default => nil
  opt :hide, "Hide columns (eg: -h 'foo; bar')", :type => :string, :default => nil
  opt :regex, "Show/Hide column names by regex, not by exact name, e.g. -r -o 'comb.+'", :type => :boolean, :default => false
  opt :command, "Commands to include/override. e.g. -c 'set log x; set label \"data\"'", :type => :string, :default => ""
  opt :add, "Additional columns/functions to plot. e.g. -a '1+sin($2); log($4-$3) title \"log diff\"'", :type => :string, :default => ""
end


# TODO: plot command should be its own class instead of an array pair.
# This may be the LISP rubbing off on me, but plots is an array of
# pairs, of [column, title]. E.g. to plot using 1:3 title "pants",
# plots should contain an element [2, "pants"]. I'm adding a .second
# method to Array because I anticipate adding a third column to
# override the plot style, e.g. [2, "pants", "lines"]. If/when that
# happens, I don't want to be stuck using "last" when I mean "second".
#
# DEAR DAVE: Okay, seriously, when you make this change (and my
# money's on YAGNI) please remember that comments are a code smell and
# obviate this long-winded explication by simply promoting this to a
# class of its own. LOVE, DAVE
class Array
  def second
    self[1]
  end
end


raise "Error: Options only and hide are mutually exclusive. Use one or the other but not both." if opts[:only] && opts[:hide]

plots = []
commands = opts[:command].split(/;/).map {|s| s.strip }
commands << "set xrange [#{opts[:xrange]}]; " if opts[:xrange]

# puts ARGV[0]
File.open(ARGV[0]) do |file|
  i = 0
  while (line = file.readline)
    break unless line.grep(/^#/)[0]
#     puts line
    if line.grep(/# LEGEND:/)[0]
      index = 2
      plots = line.split(/:/,2)[1].split(/;/).map {|c| c.strip }
      plots = (1..plots.size).to_a.zip(plots)
    end
    if line.grep(/# COMMAND:/)[0]
      commands << line.split(/:/,2)[1].strip
    end
    i += 1
  end
end

xlabel = plots.shift.second
commands << "set xlabel \"#{xlabel}\"" unless commands.grep(/\bxlabel\b/)[0]

commands << "set title \"#{File.basename(ARGV[0], '.4nb')}\"" unless commands.grep(/\blabel\b/)[0]

# puts '-' * 80
# puts "Plots:"
# puts plots.map { |c| "    #{c.first}: #{c.second}"}
# puts '-' * 80
# puts "Commands:"
# puts commands.map { |c| "    #{c}"}

plot_cmd = if commands
             (commands * "; ") + '; '
           else
             ""
           end
plot_cmd += "plot "

if opts[:only]
#   puts "*** Option ONLY detected!"
#   puts "Keepers:"
#   puts to_keep.map { |t| "    #{t.inspect}"}
  to_keep = opts[:only].split(/;/).map {|t| t.strip}
  if opts[:regex]
    # regex was specified. Expand the regex list into explicit plot names
    to_keep = to_keep.map {|k| plots.map{|c| c.second}.grep(Regexp.new(k))}.inject {|a,b| a | b }
  end
  plots = plots.select {|c| to_keep.include?(c.second)}
elsif opts[:hide]
#   puts "*** Option HIDE detected!"
#   puts "Hiders:"
#   puts to_hide.map { |t| "    #{t.inspect}"}
  to_hide = opts[:hide].split(/;/).map {|t| t.strip}
  if opts[:regex]
    # regex was specified. Expand the regex list into explicit plot names
    to_hide = to_hide.map {|k| plots.map{|c| c.second}.grep(Regexp.new(k))}.inject {|a,b| a | b }
  end
  plots = plots.reject {|c| to_hide.include?(c.second)}
end

# Now add in user-added plots
# KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!
# KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!
# KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!
# KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!
# KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!
# KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!  KLUD WRITE ME!
plots += opts[:add].split(/;/).map {|a| a.strip }.map {|a| a =~ /\btitle\b/ ? a.split(/\btitle\b/, 2) : [a,a] }.map {|a,b| ["(#{a})", b] }

plot_cmd += plots.map { |plot| "\"#{ARGV[0]}\" using 1:#{plot.first} title \"#{plot.second}\" with lines"} * ', '

# plot_cmd = <<PLOT
# plot "#{ARGV[0]}" using 1:7 title "sum" with lines, "#{ARGV[0]}" using 1:8 title "avg" with lines, "#{ARGV[0]}" using 1:9 title "product" with lines
# PLOT

plot_cmd.strip!

cmd = "gnuplot -p -e '#{plot_cmd}'"
puts cmd
system "#{cmd}"
