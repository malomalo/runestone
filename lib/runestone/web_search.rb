# frozen_string_literal: true

class Runestone::WebSearch
  
  autoload :Parser, "#{File.dirname(__FILE__)}/web_search/parser"
  autoload :Match, "#{File.dirname(__FILE__)}/web_search/match"
  autoload :PartialMatch, "#{File.dirname(__FILE__)}/web_search/partial_match"
  
  attr_reader :root
  
  def initialize(root_node)
    @root = root_node
  end

  def self.parse(query)
    Runestone::WebSearch::Parser.parse(query)
  end
  
  def prefix(mode = :last)
    Runestone::WebSearch.new(root.prefix(mode))
  end
  
  def typos
    Runestone::WebSearch.new(root.with_typo_correction)
  end

  def synonymize
    Runestone::WebSearch.new(root.synonymize)
  end

  def to_s(use_synonyms: true, allow_typos: true)
    root.to_s
  end

end
