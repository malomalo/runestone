class Runestone::Node::Token < Runestone::Node
  
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
        "#{value}:* | #{alts.map(&:to_s).join(' | ')}"
      end
    else
      if alts.empty?
        value
      else
        "#{value} | #{alts.map(&:to_s).join(' | ')}"
      end
    end
  end
  
  def each_variation
    yield value
    alts.each { |alt| yield(alt) }
  end
  
  def prefix!(mode = nil)
    @prefix = true
  end
  
  def corpus(set = Set.new)
    set << @value if !@negative
    set
  end
  
  def with_typo_correction(typos = self.typos)
    if !@negative && typos.has_key?(@value)
      Runestone::Node::Token.new(@value, prefix: @prefix, alts: typos[@value])
    else
      self
    end
  end

  def token?
    true
  end
  
  def size
    1 + alts.size
  end

  def synonymize
    Runestone::Node::Or.new(*synonymize_parts([self]), negative: @negative)
  end

end