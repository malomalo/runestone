class Runestone::WebSearch::And < Runestone::WebSearch::Boolean

  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map(&:to_s).join(' & ')
    end

    negative ? "!#{v}" : v
  end

end