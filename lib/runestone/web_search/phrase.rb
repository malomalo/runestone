class Runestone::WebSearch::Phrase
  attr_accessor :values, :prefix, :negative, :distance
  def initialize(values, prefix: false, negative: false, distance: nil)
    @values = values
    @prefix = prefix
    @negative = negative
    @distance = distance
  end
  
  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      seperator = distance ? " <#{distance}> " : ' <-> '
      "(#{values.map(&:to_s).join(seperator)})"
    end
    negative ? "!#{v}" : v
  end
end