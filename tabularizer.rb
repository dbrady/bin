# tabular - Given a list of items, output that list as a VERTICALLY
# sorted table that fits on the console. For example, if the console
# were 60 columns wide, and we gave it the following list:
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
# Right now, the columns are all the same width, but ideally I'd like
# to shape the text a little tighter so that each column is only as
# wide as its longest element. This would make for a slightly less
# deterministic algorithm (essentially it would need to add columns
# until the next column does not fit)

# TODO: Size each column to fit in order to get more columns. For
# example, when dumping ruby methods, the first twenty or so methods
# are often "!", "!=", "!~", "<=>", "==", "===", etc, which fill up
# the first column. One braindead algorithm to try doing this is to
# do the standard division, then ask each word stack how wide it
# is. We sum these and add stacks-1, and if it's <= width, then it
# fits. So we forcibly increase the number of columns and
# remeasure. Beware that this also requires that each stack have its
# own format_string corresponding to its length.

require 'io/console'

class Tabularizer
  attr_reader :wordlist, :width

  def initialize(wordlist, width=$stdout.winsize.last)
    @wordlist, @width = wordlist, width
  end

  # This is a BIT tricky; we need to divide the width by the length of
  # the longest word AND consider that we need n-1 spaces left
  # over. This isn't as hard as it sounds, however: just add one to
  # the longest word length. The careful reader will note that this
  # would always leave us with a blank column at the right of the
  # table, which is why we ALSO add one to the width attribute. ;-)
  def columns
    (width+1)/column_width
  end

  def column_width
    longest_word_length + 1
  end

  def words_per_column
    (wordlist.size.to_f / columns).ceil
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
    stacks = wordlist.each_slice(words_per_column)
    stacks.first.size.times do |row_index|
      str += stacks.map { |stack| format_string % stack[row_index] } * ' '
      str += "\n"
    end
    str
  end
end
