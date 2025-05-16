# frozen_string_literal: true

class Runestone::WebSearch::Match

  attr_accessor :index, :substitution

  def initialize(index, substitution)
    @index = index
    @substitution = substitution
  end

end