class Runestone::WebSearch::And
  attr_accessor :values, :negative
  def initialize(values, negative: false)
    @values = values
    @negative = negative
  end
  
  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map(&:to_s).join(' & ')
    end

    negative ? "!#{v}" : v
  end
end