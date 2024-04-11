class Runestone::WebSearch::Boolean < Runestone::WebSearch::Node

  attr_accessor :values, :negative

  def initialize(values = [], negative: false)
    @values = Array(values)
    @negative = negative
  end

  def <<(value)
    @values << value
  end
end