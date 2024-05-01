class Runestone::Node::Phrase < Runestone::Node

  attr_accessor :values, :negative, :distance

  def initialize(*values, prefix: false, negative: false, distance: nil)
    @values = values
    @prefix = prefix
    @negative = negative
    @distance = distance
  end
  
  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map(&:to_s).join(seperator)
    end
    negative ? "!(#{v})" : v
  end
  
  def empty?
    @values.empty?
  end
  
  def corpus(set = Set.new)
    set
  end
  
  def <<(value)
    @values << value
  end
  
  def size
    @values.size
  end
  
  def seperator
    distance ? " <#{distance}> " : ' <-> '
  end
end