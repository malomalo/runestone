module Runestone::Corpus

  def self.add(*words)
    return if words.size == 0

    conn = Runestone::Model.connection
    conn.execute(<<-SQL)
      INSERT INTO runestone_corpus ( word )
      VALUES (#{words.map { |w| conn.quote(Runestone.normalize(w)) }.join('),(')})
      ON CONFLICT DO NOTHING
    SQL
  end

  def self.similar_words(*words)
    lut = {}
    conn = Runestone::Model.connection
    words = words.inject([]) do |ws, w|
      tt = typo_tolerance(w)
      ws << "#{conn.quote(w)}, #{conn.quote(w.downcase)}, #{tt}" if tt > 0
      ws
    end
    return lut if words.size == 0
    
    result = conn.execute(<<-SQL)
      WITH  tokens (token, token_downcased, typo_tolerance) AS (VALUES (#{words.join('), (')}))
      SELECT token, word, levenshtein(runestone_corpus.word, tokens.token_downcased)
      FROM tokens
      JOIN runestone_corpus ON runestone_corpus.word % tokens.token_downcased
      WHERE
        runestone_corpus.word != tokens.token_downcased
        AND levenshtein(runestone_corpus.word, tokens.token_downcased) <= tokens.typo_tolerance
    SQL
    result.each_row do |t, w, l|
      w.gsub!(/\(|\)|:|\||!|\&|\*/, '')
      next if w == t
      lut[t] ||= []
      lut[t] << w
    end
    lut
  end

  def self.typo_tolerance(word)
    Runestone.typo_tolerances.find { |k,v| v.member?(word.length) }&.first || 0
  end
  
end