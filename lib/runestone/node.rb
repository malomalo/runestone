class Runestone::Node

  autoload :Or, "#{File.dirname(__FILE__)}/node/or"
  autoload :And, "#{File.dirname(__FILE__)}/node/and"
  autoload :Token, "#{File.dirname(__FILE__)}/node/token"
  autoload :Boolean, "#{File.dirname(__FILE__)}/node/boolean"
  autoload :Phrase, "#{File.dirname(__FILE__)}/node/phrase"

  def token?
    false
  end

  def prefix(mode)
    self
  end

  def corpus(set = Set.new)
    @values.each do |value|
      value.corpus(set)
    end
    set
  end
  
  def typos
    Runestone::Corpus.similar_words(*corpus)
  end
  
  def with_typo_correction(typos = self.typos)
    self.class.new(*values.map { |node| node.with_typo_correction(typos) })
  end
  
  def synonymize
    self
  end
  
  def synonymize_parts(part)
    pending_matches = []
    matches = []

    part.each_with_index do |node, i|
      pending_matches = pending_matches.inject([]) do |memo, match|
        if node.token? && !node.negative && match.end_index + 1 == i
          node.each_variation do |variation|
            if match.substitution[variation]
              match.substitution[variation].map do |nm|
                if nm.is_a?(Hash)
                  memo << Runestone::WebSearch::PartialMatch.new(match.start_index, i, nm)
                else
                  matches << Runestone::WebSearch::Match.new(match.start_index..i, Runestone::Node::Phrase.new(*nm.split(/\s+/), distance: 1))
                end
              end
            end
          end
          
        end
        memo
      end

      if node.token? && !node.negative
        node.each_variation do |variation|
          Runestone.synonyms[variation]&.each do |m|
            if m.is_a?(Hash)
              pending_matches << Runestone::WebSearch::PartialMatch.new(i, i, m)
            else
              matches << Runestone::WebSearch::Match.new(i, Runestone::Node::Phrase.new(*m.split(/\s+/), distance: 1))
            end
          end
        end
      end
    end

    matches.select! do |match|
      if match.index.is_a?(Integer)
        case part[match.index]
        when Runestone::Node::Or
          part[match.index] = Runestone::Node::Or.new(*part[match.index].values, *match.substitution)
        else
          part[match.index] = Runestone::Node::Or.new(*part[match.index], *match.substitution)
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
      Runestone::Node::And.new(*part)
    else
      orrs = Runestone::Node::Or.new

      groups.each do |g|
        p = Runestone::Node::And.new
        p.values.push(*part[0..g.first.index.begin-1]) if g.first.index.begin > 0
        range = nil
        p.values << Runestone::Node::Or.new
        g.inject(p.values.last) do |orr, m|
          new_or = if range.nil? || range == m.index
            orr << m.substitution
          else
            o = Or.new(*part[m.index.end..range.begin])
            orr << o
            o << m.substitution
          end
          range = m.index
          new_or
        end
        p.values.last.values.unshift(Runestone::Node::And.new(*part[range]))# if range.size > 1

        p.values.push(*part[g.last.index.end+1..-1]) if g.last.index.end < part.size
        orrs.values << p
      end
      orrs
    end
  end
  
end