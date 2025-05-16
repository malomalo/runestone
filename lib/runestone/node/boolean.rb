# frozen_string_literal: true

class Runestone::Node::Boolean < Runestone::Node

  attr_accessor :values, :negative

  def initialize(*values, negative: false)
    @values = values
    @negative = negative
  end

  def <<(value)
    @values << value
  end
  
  def size
    @values.size
  end
end