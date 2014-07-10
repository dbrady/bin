# vertable - Given a list of items, output that list as a vertically
# sorted table that fits on the console. I.e. it displays a list of
# strings on the console the same way that `ls` does. For example, if
# the console were 60 columns wide, and we gave it the following list:
#
# aardvark, aardwolf, Aaron, Aaronic, Aaronical, Aaronite, Aaronitic,
# Aaru, Ab, aba, Ababdeh, Ababua, abac, abaca, abacate, abacay,
# abacinate, abacination, abaciscus, abacist, aback, abactinal,
# abactinally, abaction, abactor, abaculus, abacus, Abadite, abaff,
# abaft


# The tabular output would look like this:
#
# |<-------------------------- (60) -------------------------->|
# |Aaron       Ab          aba         abacination abaction    |
# |Aaronic     Ababdeh     abac        abaciscus   abactor     |
# |Aaronical   Ababua      abaca       abacist     abaculus    |
# |Aaronite    Abadite     abacate     aback       abacus      |
# |Aaronitic   aardvark    abacay      abactinal   abaff       |
# |Aaru        aardwolf    abacinate   abactinally abaft       |
#
# TODO: Right now all columns are the same size, the way ls does. This
# is easy, but a waste of space. Size each column to fit in order to
# get more columns. For example, when dumping ruby methods, the first
# twenty or so methods are often "!", "!=", "!~", "<=>", "==", "===",
# etc, which fill up the first column. One braindead algorithm to try
# doing this is to do the standard division, then ask each word stack
# how wide it is. We sum these and add stacks-1, and if it's <= width,
# then it fits. So we forcibly increase the number of columns and
# remeasure. Beware that this also requires that each stack have its
# own format_string corresponding to its length.

require 'io/console'

class Vertable
  attr_reader :wordlist, :width

  def initialize(wordlist, width=$stdout.winsize.last)
    @wordlist, @width = wordlist, width
  end

  # Number of columns of words on the screen. Add 1 to width to allow
  # for the fact that column_width adds 1 space per word, but we don't
  # need the last space--it pads against the right edge.
  def num_columns
    (width+1)/column_width
  end

  # Width of a column in characters--including the padding char
  def column_width
    longest_word_length + 1
  end

  def words_per_column
    (wordlist.size.to_f / num_columns).ceil
  end

  def longest_word_length
    @longest_word_length ||= longest_word.size
  end

  def longest_word
    @longest_word ||= wordlist.sort_by(&:size).last
  end

  def format_string
    "%-#{longest_word_length}s"
  end

  def to_s
    str = ''
    columns = wordlist.each_slice(words_per_column)
    columns.first.size.times do |row_index|
      str += columns.map { |column| format_string % column[row_index] } * ' '
      str += "\n"
    end
    str
  end
end
