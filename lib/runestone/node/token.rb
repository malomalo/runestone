# frozen_string_literal: true

class Runestone::Node::Token < Runestone::Node
  
  attr_accessor :value, :negative, :alts

  def initialize(value, prefix: false, negative: false, alts: nil)
    @value = value
    @prefix = prefix
    @negative = negative
    @alts = alts || []
  end

  # If needed more quoting can add wrap in a single quote ie: "'#{token}'"
  def quote(token)
    token.gsub(/[\\\(\):\|!\&\*]/) { |a| "\\#{a}" }
  end
  
  def to_s
    if negative
      "!#{quote(value)}"
    elsif @prefix
      if alts.empty?
        "#{quote(value)}:*"
      else
        "#{quote(value)}:* | #{alts.map{|a| quote(a)}.join(' | ')}"
      end
    else
      if alts.empty?
        quote(value)
      else
        "#{quote(value)} | #{alts.map{|a| quote(a)}.join(' | ')}"
      end
    end
  end
  
  def each_variation
    yield value
    alts.each { |alt| yield(alt) }
  end
  
  def prefix(mode)
    if mode != :none && !@negative && !@prefix
      Token.new(@value, prefix: true, negative: @negative, alts: @alts)
    else
      self
    end
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