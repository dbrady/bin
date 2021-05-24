class Scale
  SCALE = %w( A Bb B C C# D Eb E F F# G G# )

  def self.valid?(key)
    valid_scales.include?(key)
  end

  def self.valid_scales
    SCALE.map {|scale|
      ['', 'm', 'dim', "pent"].map {|mode|
        "#{scale}#{mode}"
      }
    }.flatten
  end
end
