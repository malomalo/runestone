class Runestone::WebSearch::Node

  def phrase?
    false
  end

  def token?
    false
  end

  def prefix!(mode = :last)
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
      pending_matches.select! do |match|
        if node.token? && match.end_index + 1 == i && match.substitution[node.value]
          match.substitution[node.value].map do |nm|
            if nm.is_a?(Hash)
              match.end_index = i
              match.alts = nm
              true
            else
              matches << Runestone::WebSearch::Match.new(match.start_index..i, Runestone::WebSearch::Phrase.new(*nm.split(/\s+/), distance: 1))
              false
            end
          end
        else
          false
        end
      end

      if node.token? && !node.negative && match = Runestone.synonyms[node.value]
        match.each do |m|
          if m.is_a?(Hash)
            pending_matches << Runestone::WebSearch::PartialMatch.new(i, i, m)
          else
            matches << Runestone::WebSearch::Match.new(i, Runestone::WebSearch::Phrase.new(*m.split(/\s+/), distance: 1))
          end
        end
      end
    end

    matches.select! do |match|
      if match.index.is_a?(Integer)
        case part[match.index]
        when Runestone::WebSearch::Or
          part[match.index] = Runestone::WebSearch::Or.new(*part[match.index].values, *match.substitution)
        else
          part[match.index] = Runestone::WebSearch::Or.new(*part[match.index], *match.substitution)
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
      Runestone::WebSearch::And.new(*part)
    else
      orrs = Runestone::WebSearch::Or.new

      groups.each do |g|
        p = Runestone::WebSearch::And.new
        p.values.push(*part[0..g.first.index.begin-1]) if g.first.index.begin > 0
        range = nil
        p.values << Runestone::WebSearch::Or.new
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
        p.values.last.values.unshift(Runestone::WebSearch::And.new(*part[range]))# if range.size > 1

        p.values.push(*part[g.last.index.end+1..-1]) if g.last.index.end < part.size
        orrs.values << p
      end
      orrs
    end
  end
  
end