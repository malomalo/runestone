# frozen_string_literal: true

require 'stream_parser'

class Runestone::WebSearch::Parser
  
  include StreamParser

  # TODO:
  # For now we can't search for tokens (ie /, (, ), &, etc...), i think we
  # will need to use $$ string and write our own pg parser to search them re:
  # https://dba.stackexchange.com/questions/180303/how-can-i-query-for-terms-like-foo-with-postgres-full-text-search
  #
  # https://web.archive.org/web/20250731140352/https://dba.stackexchange.com/questions/180303/how-can-i-query-for-terms-like-foo-with-postgres-full-text-search  
  def initialize(query)
    @source = Runestone.normalize(query)
    # @source.gsub!(/\(|\)|:|\'|!|\&|\*/, '')
    @source.gsub!(/(\A|[[:blank:]])[']/, '\1')
    seek(0)
  end

  def parse
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
          next_leaf = @query.pop
          if @stack.last == :or
            @query.last << next_leaf
            @query << Runestone::Node::And.new
          else
            @stack << :or
            @query << Runestone::Node::Or.new(next_leaf) << Runestone::Node::And.new
          end
        else
          @query.last << Runestone::Node::Token.new(
            match,
            negative: knot
          )
        end
      end
    end
    
    # Check for unfinished empty phrases and remove it
    if @query.last.is_a?(Runestone::Node::Phrase)
      @query.pop if @query.last.values.empty?
    end

    case @stack.last
    when :or
      @stack.pop
      phrase = @query.pop
      @query.last << phrase
    when :double_quote
      if @query.size > 1
        phrase = @query.pop
        @query.last << phrase
      end
    end

    root = if @query.last.is_a?(Runestone::Node::Boolean) && @query.last.size == 1
      @query.last.values.first
    else
      @query.last
    end
    
    Runestone::WebSearch.new(root)
  end

end