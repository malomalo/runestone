class Runestone::WebSearch::Or < Runestone::WebSearch::Boolean

  def to_s
    "(#{values.map(&:to_s).join(' | ')})"
  end

  def prefix!(mode = :last)
    values.each { |node| node.prefix!(mode) }
  end

  def synonymize
    new_parts = @values.map do |node|
      node.token? && node.negative ? node : node.synonymize
    end

    Runestone::WebSearch::Or.new(*new_parts, negative: @negative)
  end

end