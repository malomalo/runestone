class Runestone::WebSearch::And < Runestone::WebSearch::Boolean

  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map(&:to_s).join(' & ')
    end

    negative ? "!#{v}" : v
  end

  def prefix!(mode = :last)
    values.last.prefix!(mode)
  end

  def synonymize
    Runestone::WebSearch::And.new(*synonymize_parts(@values.dup), negative: @negative)
  end

end