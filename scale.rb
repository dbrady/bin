class Scale
  SCALE = %w( A Bb B C Db D Eb E F Gb G Ab )
  # TODO: fretmap has a bug, it needs SCALE to have exactly 12 tones because it
  # counts its way up the scale, so if I put A, A#, Bb, B, it will incorrectly
  # conflate these 2 names with there being 2 semitones between A and
  # B. :facepalm: Look for the line of code like `scale =
  # Scale::SCALE.cycle`. One way to fix it might be to have instances of Scale
  # that can be sharp or flat?
  SHARP_SCALE = %w( A A# B C C# D D# E F F# G G# )
  FLAT_SCALE  = %w( A Bb B C Db D Eb E F Gb G Ab )

  NOTE_NAMES = (SHARP_SCALE + FLAT_SCALE).uniq.sort


  def initialize(sharp_or_flat)
    raise ArgumentError.new("sharp_or_flat must be one of [:sharp, :flat]") unless [:sharp, :flat].include?(sharp_or_flat)

    @sharp_or_flat = sharp_or_flat
  end

  def sharp?
    @sharp_or_flat == :sharp
  end

  def flat?
    !sharp?
  end

  def notes
    if sharp?
      SHARP_SCALE
    else
      FLAT_SCALE
    end
  end

  # FIXME: These are the notes for the diatonic major / ionian mode
  # only. There's a BUNCH of keys and scales out there, Cotton!
  NOTES_FOR_KEYS = {
      'Cb' => 'Cb Db Eb Fb Gb Ab Bb', # 7 flats
      'C' => 'C D E F G A B', # All natural, baby
      'C#' => 'C# D# E# F# G# A# B#', # 7 sharps
      'Db' => 'Db Eb F Gb Ab Bb C', # 5 flats
      'D' => 'D E F# G A B C#', # 2 sharps
      # 'D#' => 'D# E# F## G# A# B# C##', # 'D#' exists, and is in NINE sharps (All sharps plus F## and C##), but we short out the circle of 5ths at C#
      'Eb' => 'Eb F G Ab Bb C D',
      'E' => 'E F# G# A B C# D#',
      # 'E#' => exists and is in 11 sharps, lol
      # 'Fb' => exists and is in 8 flats
      'F' => 'F G A Bb C D E',
      'F#' => 'F# G# A# B C# D# E#',
      'Gb' => 'Gb Ab Bb Cb Db Eb F',
      'G' => 'G A B C D E F#',
      # 'G#' => 'G# A# B# C# D# E# F##', # exists, and is in 8 sharps
      'Ab' => 'Ab Bb C Db Eb F G', # 4 flats
      'A' => 'A B C# D E F# G#', # 3 sharps
      # 'A#' => 'A# B# C## D# E# F## G##', # TEN! TEN SHARPS! AH!-AH!-AHHHH!
      'Bb' => 'Bb C D Eb F G A',
      'B' => 'B C# D# E F# G# A#',
      # 'B#' # 12 sharps. Oh my head. B# and E# are the only not-double-sharp notes.
  }.freeze

  def self.notes_for_key(key)
    raise ArgumentError.new("#{key} is not a normal key, must be one of: #{NOTES_FOR_KEYS.keys.sort.join(', ')}") unless valid_key?(key)
    NOTES_FOR_KEYS.fetch(key).split
  end

  def self.valid_key?(key)
    NOTE_NAMES.include?(key)
  end

  def self.valid_scales
    NOTE_NAMES.map {|scale|
      ['', 'm', "pent"].map {|mode|
        "#{scale}#{mode}"
      }
    }.flatten
  end
end
