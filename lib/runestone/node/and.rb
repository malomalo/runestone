# frozen_string_literal: true

class Runestone::Node::And < Runestone::Node::Boolean

  def to_s
    v = if values.size == 1
      values.first.to_s
    else
      values.map do |node|
        if node.is_a?(Runestone::Node::Phrase) || node.size == 1
          node.to_s
        else
          "(#{node.to_s})"
        end
      end.join(' & ')
    end

    negative ? "!#{v}" : v
  end

  def prefix(mode)
    case mode
    when :last
      last = @values.last
      new_and = And.new(*@values[0..-2])
      new_and << last.prefix(mode)
      new_and
    when :all
      And.new(*values.map { |node| node.prefix(mode) })
    else
      self
    end
  end

  def synonymize
    Runestone::Node::And.new(*synonymize_parts(@values.dup), negative: @negative)
  end

end