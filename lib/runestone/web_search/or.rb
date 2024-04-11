class Runestone::WebSearch::Or < Runestone::WebSearch::Boolean

  def to_s
    "(#{values.map(&:to_s).join(' | ')})"
  end

end