require 'stream_parser'

class Runestone::WebSearch::Parser
  
  include StreamParser
  
  def initialize(query)
    @source = Runestone.normalize!(query)
    seek(0)
  end

  def parse(prefix: :last)
    prefix ||= :last

    @stack = []
    @query = [Runestone::Node::And.new]

    while !eos?
      case @stack.last
      when :double_quote
        case scan_until(/("|\Z|[^[[:space:]]"]+)/)[0]
        when '"', ''
          @stack.pop
          phrase = @query.pop
          if !phrase.empty?
            @query.last << phrase
          end
        else
          @query.last << Runestone::Node::Token.new(match)
        end

      else
        knot = if @stack.last == :not
          @stack.pop
          true
        else
          false
        end
         
        case scan_until(/(["\-|]|[^[[:space:]]|]+)/)[0]
        when '-'
          @stack << :not
        when '"'
          @stack << :double_quote
          @query << Runestone::Node::Phrase.new(negative: knot)
        when "|"
          @stack << :or
          @query << Runestone::Node::Or.new(@query.pop) if !@query.last.is_a?(Runestone::Node::Or)
          @query << Runestone::Node::And.new
        else
          @query.last << Runestone::Node::Token.new(
            match,
            negative: knot,
            prefix: !knot && prefix == :all
          )
        end
      end
    end
    
    # Check for unfinished empty phrases and remove it
    if @query.last.is_a?(Runestone::Node::Phrase)
      @query.pop if @query.last.values.empty?
    end

    while !@stack.empty?
      case @stack.pop
      when :or
        phrase = @query.pop
        @query.last << phrase
      end
    end

    @query.last.prefix!(:last) if prefix == :last
    
    Runestone::WebSearch.new(@query.last)
  end

end