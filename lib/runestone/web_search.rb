require 'stream_parser'

class Runestone::WebSearch
  
  autoload :Or, "#{File.dirname(__FILE__)}/web_search/or"
  autoload :And, "#{File.dirname(__FILE__)}/web_search/and"
  autoload :Token, "#{File.dirname(__FILE__)}/web_search/token"
  autoload :Phrase, "#{File.dirname(__FILE__)}/web_search/phrase"
  autoload :Parser, "#{File.dirname(__FILE__)}/web_search/parser"
  autoload :Match, "#{File.dirname(__FILE__)}/web_search/match"
  autoload :Node, "#{File.dirname(__FILE__)}/web_search/node"
  autoload :Boolean, "#{File.dirname(__FILE__)}/web_search/boolean"
  autoload :PartialMatch, "#{File.dirname(__FILE__)}/web_search/partial_match"
  
  attr_accessor :values
  
  def initialize(values)
    @values = values
  end

  # prefix options: :all, :last, :none (default: :last)
  # token.gsub!(/\(|\)|:|\||!|\&|\*/, '')
  def self.parse(query, prefix: :last)
    Runestone::WebSearch::Parser.parse(query, prefix: prefix)
  end

  def postivie_tokens(tokens = @values, return_value = [])
    case tokens
    when Array
      tokens.each { |token| postivie_tokens(token, return_value) }
    when Runestone::WebSearch::Boolean
      tokens.values.each { |token| postivie_tokens(token, return_value) } if !tokens.negative
    when Phrase
    else
      return_value << tokens if !tokens.negative
    end
    return_value
  end
  
  def clone_nodes(nodes = @values, &block)
    nodes.map do |node|
      case node
      when Boolean
        yield node.class.new(clone_nodes(node.values, &block), negative: node.negative)
      else
        yield node
      end
    end
  end
  
  def typos
    tokens = postivie_tokens
    sw = Runestone::Corpus.similar_words(*tokens.map(&:value))
    q = clone_nodes do |t|
      if t.is_a?(Token) && sw.has_key?(t.value)
        Token.new(t.value, prefix: t.prefix, negative: t.negative, alts: sw[t.value])
      else
        t
      end
    end
    
    Runestone::WebSearch.new(q)
  end

  def synonymize
    parts = []
    @values.each do |token|
      if token.is_a?(Phrase) || token.is_a?(Boolean) || (token.is_a?(Token) && token.negative)
        parts << token
      else
        parts << [] if parts.empty? || parts.last.is_a?(Phrase) || (!parts.last.is_a?(Array) && parts.last.negative)
        parts.last << token
      end
    end

    parts.map! do |part|
      synonymize_part(part)
    end

    Runestone::WebSearch.new(parts)
  end

  def synonymize_part(part)
    case part
    when Array
      synonymize_webserach(part)
    when Or
      part.class.new(part.values.map { |p| p.negative ? p : synonymize_part(p) }, negative: part.negative)
    when And
      part.class.new(synonymize_part(part.values.dup), negative: part.negative)
    else
      part
    end
  end
  
  def synonymize_webserach(part)
    pending_matches = []
    matches = []

    part.each_with_index do |token, i|
      pending_matches.select! do |match|
        if match.end_index + 1 == i && match.substitution[token.value]
          match.substitution[token.value].map do |nm|
            if nm.is_a?(Hash)
              match.end_index = i
              match.alts = nm
              true
            else
              matches << Match.new(match.start_index..i, Phrase.new(nm.split(/\s+/), distance: 1))
              false
            end
          end
        else
          false
        end
      end

      if !token.negative && !token.phrase? && match = Runestone.synonyms[token.value]
        match.each do |m|
          if m.is_a?(Hash)
            pending_matches << PartialMatch.new(i, i, m)
          else
            matches << Match.new(i, Phrase.new(m.split(/\s+/), distance: 1))
          end
        end
      end
    end

    matches.select! do |match|
      if match.index.is_a?(Integer)
        case part[match.index]
        when Or
          part[match.index] = Or.new(part[match.index].values + [match.substitution])
        else
          part[match.index] = Or.new([part[match.index], match.substitution])
        end
        false
      else
        true
      end
    end

    groups = matches.sort_by { |m| -m.index.size}.inject([]) do |memo, match|
      if i = memo.index { |k| k.all? { |j| j.index.cover?(match.index) } }
        memo[i] << match
      elsif i = memo.index { |k| k.none? { |j| j.index.overlaps?(match.index) } }
        memo[i] << match
      else
        memo << [match]
      end
      memo
    end

    if groups.empty?
      And.new(part)
    else
      orrs = Or.new([])

      groups.each do |g|
        p = And.new
        p.values.push(*part[0..g.first.index.begin-1]) if g.first.index.begin > 0
        range = nil
        p.values << Or.new
        g.inject(p.values.last) do |orr, m|
          new_or = if range.nil? || range == m.index
            orr << m.substitution
          else
            o = Or.new(part[m.index.end..range.begin])
            orr << o
            o << m.substitution
          end
          range = m.index
          new_or
        end
        p.values.last.values.unshift(And.new(part[range]))# if range.size > 1

        p.values.push(*part[g.last.index.end+1..-1]) if g.last.index.end < part.size
        orrs.values << p
      end
      orrs
    end
  end

  def to_s(use_synonyms: true, allow_typos: true)
    self.values.join(' & ')
  end
end
