class Runestone::WebSearch
  
  autoload :Or, "#{File.dirname(__FILE__)}/web_search/or"
  autoload :And, "#{File.dirname(__FILE__)}/web_search/and"
  autoload :Token, "#{File.dirname(__FILE__)}/web_search/token"
  autoload :Phrase, "#{File.dirname(__FILE__)}/web_search/phrase"
  autoload :Parser, "#{File.dirname(__FILE__)}/web_search/parser"
  autoload :Match, "#{File.dirname(__FILE__)}/web_search/match"
  autoload :Node, "#{File.dirname(__FILE__)}/web_search/node"
  autoload :Boolean, "#{File.dirname(__FILE__)}/web_search/boolean"
  autoload :PartialMatch, "#{File.dirname(__FILE__)}/web_search/partial_match"
  
  attr_reader :root
  
  def initialize(root_node)
    @root = root_node
  end

  # prefix options: :all, :last, :none (default: :last)
  def self.parse(query, prefix: :last)
    Runestone::WebSearch::Parser.parse(query, prefix: prefix)
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
