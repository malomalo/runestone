class Runestone::Node::Or < Runestone::Node::Boolean

  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map do |node|
        node.is_a?(Runestone::Node::Boolean) ? "(#{node.to_s})" : node.to_s
      end.join(' | ')
    end

    negative ? "!(#{v})" : v
  end

  def prefix!(mode = :last)
    values.each { |node| node.prefix!(mode) }
  end

  def synonymize
    new_parts = @values.map do |node|
      node.token? && node.negative ? node : node.synonymize
    end

    Runestone::Node::Or.new(*new_parts, negative: @negative)
  end

end