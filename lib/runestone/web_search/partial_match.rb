class Runestone::WebSearch::PartialMatch
  attr_accessor :start_index, :end_index, :substitution
  def initialize(start_index, end_index, substitution)
    @start_index = start_index
    @end_index = end_index
    @substitution = substitution
  end
end