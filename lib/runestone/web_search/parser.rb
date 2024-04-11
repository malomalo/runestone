class Runestone::WebSearch::Parser
  
  include StreamParser
  
  def initialize(query)
    @source = Runestone.normalize!(query)
    seek(0)
  end

  def parse(prefix: :last)
    prefix ||= :last
  
    @q = []
    @stack = []
    
    while !eos?
      case @stack.last
      when :double_quote
        scan_until(/("|\Z|\s+)/)
        
        @q.last.values << pre_match if !pre_match.empty?
        if match == '"' || match == ''
          @stack.pop
          @q.pop if @q.last.values.empty?
        end

      else
        knot = if @stack.last == :not
          @stack.pop
          true
        else
          false
        end
        
        token = scan_until(/(["\-|]|[^[[:space:]]|]+)/)[0]
        case token
        when '-'
          @stack << :not
        when '"'
          @stack << :double_quote
          @q << Runestone::WebSearch::Phrase.new([], negative: knot)
        when "|"
          @q = [Runestone::WebSearch::Or.new(Runestone::WebSearch::And.new(@q))]
          @stack << :or
        else
          token = Runestone::WebSearch::Token.new(
            token,
            negative: knot,
            prefix: !knot && prefix == :all
          )
          
          @q << token
        end
      end
    end

    while !@stack.empty?
      case @stack.pop
      when :or
        ri = @q.rindex { |e| e.is_a?(Runestone::WebSearch::Or) }
        @q[ri].values << Runestone::WebSearch::And.new(@q.slice!((ri+1)..-1))
      end
    end
    
    if @q.last.is_a?(Runestone::WebSearch::Phrase)
      @q.pop if @q.last.values.empty?
    elsif prefix == :last
      prefix_last(@q.last)
    end
    
    Runestone::WebSearch.new(@q)
  end
  
  def prefix_last(leaf)
    case leaf
    when Runestone::WebSearch::Token
      leaf.prefix = true if !leaf.negative
    when Runestone::WebSearch::Boolean
      leaf.values.each { |l| l.is_a?(Runestone::WebSearch::Token) ? prefix_last(l) : prefix_last(l.values.last) }
    end
  end

  def quoted_value(quote_char = '"', escape_chars = ["\\"])
    ret_value = ""
    while scan_until(/(#{quote_char}|\Z)/)
      if match != quote_char
        ret_value << pre_match
        return ret_value
      elsif !escape_chars.include?(pre_match[-1])
        ret_value << pre_match
        return ret_value
      else
        ret_value << pre_match[0...-1] << match
      end
    end
  end

end