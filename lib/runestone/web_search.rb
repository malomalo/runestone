class Runestone::WebSearch
  
  autoload :Parser, "#{File.dirname(__FILE__)}/web_search/parser"
  autoload :Match, "#{File.dirname(__FILE__)}/web_search/match"
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
