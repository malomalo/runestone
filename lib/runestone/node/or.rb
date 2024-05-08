class Runestone::Node::Or < Runestone::Node::Boolean

  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map do |node|
        if node.is_a?(Runestone::Node::And) || node.is_a?(Runestone::Node::Phrase) || node.size == 1
          node.to_s
        elsif node.is_a?(Runestone::Node::Token)
          node.to_s
        else
          "(#{node.to_s})"
        end
      end.join(' | ')
    end

    negative ? "!(#{v})" : v
  end

  def prefix(mode)
    case mode
    when :last, :all
      Or.new(*values.map { |node| node.prefix(mode) })
    else
      self
    end
  end

  def synonymize
    new_parts = @values.map do |node|
      node.token? && node.negative ? node : node.synonymize
    end

    Runestone::Node::Or.new(*new_parts, negative: @negative)
  end

end