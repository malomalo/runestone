class Runestone::WebSearch::Token
  attr_accessor :value, :prefix, :negative, :alts
  def initialize(value, prefix: false, negative: false, alts: nil)
    @value = value
    @prefix = prefix
    @negative = negative
    @alts = alts || []
  end

  def to_s
    if negative
      "!#{value}"
    elsif prefix
      if alts.empty?
        "#{value}:*"
      else
        "(#{value}:* | #{alts.join(' | ')})"
      end
    else
      if alts.empty?
        value
      else
        "(#{value} | #{alts.join(' | ')})"
      end
    end
  end
end