require 'arel/extensions'

module Runestone
  
  autoload :Node, "#{File.dirname(__FILE__)}/runestone/node"
  autoload :Model, "#{File.dirname(__FILE__)}/runestone/model"
  autoload :Settings, "#{File.dirname(__FILE__)}/runestone/settings"
  autoload :WebSearch, "#{File.dirname(__FILE__)}/runestone/web_search"
  autoload :IndexingJob, "#{File.dirname(__FILE__)}/runestone/indexing_job"
  autoload :PsqlSchemaDumper, "#{File.dirname(__FILE__)}/runestone/psql_schema_dumper"
  
  mattr_accessor :dictionary, default: :runestone
  mattr_accessor :normalization, default: 16
  mattr_accessor :runner, default: :inline
  mattr_accessor :job_queue, default: :runestone_indexing
  mattr_accessor :typo_tolerances, default: { 1 => 4..7, 2 => 8.. }
  
  mattr_reader :synonyms do
    { }
  end
  
  def self.normalize(string)
    string = string.strip
    string.downcase!
    string.unicode_normalize!
    string
  rescue Encoding::CompatibilityError
    string
  end

  def self.normalize!(string)
    string.strip!
    string.downcase!
    string.unicode_normalize!
  rescue Encoding::CompatibilityError
  end

  def self.add_synonyms(dictionary)
    dictionary.each do |k, v|
      add_synonym(k, *v)
    end
  end
  
  def self.add_synonym(word, *replacements)
    word = normalize(word)
    replacements.map! { |r| normalize(r) }

    word = word.split(/\s+/)
    last = word.pop

    syn = synonyms
    word.each do |w|
      syn = if syn.has_key?(w) && h = syn[w].find { |i| i.is_a?(Hash) }
        h
      else
        h = {}
        syn[w] ||= []
        syn[w] << h
        h
      end
    end
  
    syn[last] ||= []
    syn[last] += replacements
    syn[last].uniq!
  end
  
  # prefix options: :all, :last, :none (default: :last)
  def search(query, dictionary: nil, prefix: :last, normalization: nil)
    exact_search = Runestone::WebSearch.parse(query)
    prefix_search = exact_search.prefix(prefix)
    typo_search = prefix_search.typos
    syn_search = typo_search.synonymize
    
    tsqueries = [exact_search, prefix_search, typo_search, syn_search].map(&:to_s).uniq.map do |q|
      ts_query(q, dictionary: dictionary)
    end
    
    q = if select_values.empty?
      select(
        klass.arel_table[Arel.star],
        *tsqueries.each_with_index.map { |q, i| Arel::Nodes::As.new(ts_rank_cd(:vector, q, dictionary: dictionary, normalization: normalization), Arel::Nodes::SqlLiteral.new("rank#{i}")) }
      )
    else
      select(
        *tsqueries.each_with_index.map { |q, i| Arel::Nodes::As.new(ts_rank_cd(:vector, q, dictionary: dictionary, normalization: normalization), Arel::Nodes::SqlLiteral.new("rank#{i}")) }
      )
    end

    q = if klass == Runestone::Model
      q.where(ts_match(:vector, tsqueries.last, dictionary: dictionary))
    else
      q.joins(:runestones).where(ts_match(TS::Model.arel_table['vector'], tsqueries.last, dictionary: dictionary))
    end
  
    q = q.where(dictionary: dictionary) if dictionary
      
    q.order(
      *tsqueries.each_with_index.map { |q, i| Arel::Nodes::Descending.new(Arel::Nodes::SqlLiteral.new("rank#{i}")) }
    )
  end

  
end

require 'runestone/corpus'
require 'runestone/active_record/base_methods'
require 'runestone/active_record/relation_methods'

require 'active_record'
require 'active_record/relation'
require 'active_record/querying'
ActiveRecord::Base.include Runestone::ActiveRecord::BaseMethods
ActiveRecord::Relation.include Runestone::ActiveRecord::RelationMethods
ActiveRecord::Querying.delegate :search, to: :all

require 'runestone/engine' if defined?(Rails)