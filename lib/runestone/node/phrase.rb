class Runestone::Node::Phrase < Runestone::Node

  attr_accessor :values, :prefix, :negative, :distance

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
      seperator = distance ? " <#{distance}> " : ' <-> '
      "(#{values.map(&:to_s).join(seperator)})"
    end
    negative ? "!#{v}" : v
  end
  
  def phrase?
    true
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
end