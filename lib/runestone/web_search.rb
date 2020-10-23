class Runestone::WebSearch
  autoload :Or, "#{File.dirname(__FILE__)}/web_search/or"
  autoload :And, "#{File.dirname(__FILE__)}/web_search/and"
  autoload :Token, "#{File.dirname(__FILE__)}/web_search/token"
  autoload :Phrase, "#{File.dirname(__FILE__)}/web_search/phrase"
  
  class Match
    attr_accessor :index, :substitution
    def initialize(index, substitution)
      @index = index
      @substitution = substitution
    end
  end

  class PartialMatch
    attr_accessor :start_index, :end_index, :substitution
    def initialize(start_index, end_index, substitution)
      @start_index = start_index
      @end_index = end_index
      @substitution = substitution
    end
  end

  attr_accessor :values

  # prefix options: :all, :last, :none (default: :last)
  def self.parse(query, prefix: :last)
    prefix ||= :last
    Runestone.normalize!(query)

    q = []
    stack = []
    knot = false
    tokens = query.gsub(/\"\s+\"/, '""').split(' ')
    tokens.each_with_index do |token, i|
      token.gsub!(/\(|\)|:|\||!|\&|\*/, '')
      if token.start_with?('-')
        knot = true
        token.delete_prefix!('-')
      else
        knot = false
      end
  
      next if token.empty? || token == '""' || %w(' ").include?(token)
    
      if token.start_with?('"') && token.end_with?('"')
        token.delete_prefix!('"')
        token.delete_suffix!('"')
      
        q << Phrase.new([token], negative: knot)
      elsif token.start_with?('"')
        token.delete_prefix!('"')
        stack.push(:phrase)
        q << Phrase.new([Token.new(token)], negative: knot)
      elsif token.end_with?('"')
        token.delete_suffix!('"')
        q.last.values << Token.new(token)
        stack.pop
      else
        token = Token.new(token, negative: knot)
        if !knot && prefix == :last && tokens.size - 1 == i
          token.prefix = true
        elsif !knot && prefix == :all
          token.prefix = true
        end
      
        if stack.last == :phrase
          q.last.values << token
        else
          q << token
        end
      end
    end
    
    new(q)
  end
  
  def initialize(values)
    @values = values
  end
  
  def typos
    tokens = @values.select{|t| t.is_a?(Token) && !t.negative }
    sw = Runestone::Corpus.similar_words(*tokens.map(&:value))
    q = @values.map do |t|
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
      if token.is_a?(Phrase) || token.negative
        parts << token
      else
        parts << [] if parts.empty? || parts.last.is_a?(Phrase) || (!parts.last.is_a?(Array) && parts.last.negative)
        parts.last << token
      end
    end

    parts.map! do |part|
      if !part.is_a?(Phrase) && (part.is_a?(Array) || !part.negative)
        synonymize_part(part)
      else
        part
      end
    end

    Runestone::WebSearch.new(parts)
  end

  def synonymize_part(part)
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
              matches << Match.new(match.start_index..i, Phrase.new(Array(nm), distance: 1))
              false
            end
          end
        else
          false
        end
      end

      if match = Runestone.synonyms[token.value]
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
          part[match.index].values << match.substitution
        else
          part[match.index] = Or.new([part[match.index], match.substitution])
        end

        false
      else
        true
      end
    end

    groups = matches.inject([]) do |memo, match|
      if memo.empty?
        memo << [match]
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
        p = []
        p << And.new(part[0..g.first.index.begin-1]) if g.first.index.begin > 0
        g.each do |m|
          p << Or.new([And.new(part[m.index]), m.substitution])
        end
        p << And.new(part[g.last.index.end+1..-1]) if g.last.index.end < part.size
        orrs.values << And.new(p)
      end
      orrs
    end
  end

  def to_s(use_synonyms: true, allow_typos: true)
    self.values.join(' & ')
  end
end
