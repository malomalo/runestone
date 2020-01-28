class Runestone::WebSearch::Or
  attr_accessor :values
  def initialize(values, negative: false)
    @values = values
    @negative = negative
  end
  
  def to_s
    "(#{values.map(&:to_s).join(' | ')})"
  end
end