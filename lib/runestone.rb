require 'arel/extensions'

module Runestone
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
  
  DEFAULT_APPROXIMATIONS = {
    "À"=>"A", "Á"=>"A", "Â"=>"A", "Ã"=>"A", "Ä"=>"A", "Å"=>"A", "Æ"=>"AE",
    "Ç"=>"C", "È"=>"E", "É"=>"E", "Ê"=>"E", "Ë"=>"E", "Ì"=>"I", "Í"=>"I",
    "Î"=>"I", "Ï"=>"I", "Ð"=>"D", "Ñ"=>"N", "Ò"=>"O", "Ó"=>"O", "Ô"=>"O",
    "Õ"=>"O", "Ö"=>"O", "×"=>"x", "Ø"=>"O", "Ù"=>"U", "Ú"=>"U", "Û"=>"U",
    "Ü"=>"U", "Ý"=>"Y", "Þ"=>"Th", "ß"=>"ss", "à"=>"a", "á"=>"a", "â"=>"a",
    "ã"=>"a", "ä"=>"a", "å"=>"a", "æ"=>"ae", "ç"=>"c", "è"=>"e", "é"=>"e",
    "ê"=>"e", "ë"=>"e", "ì"=>"i", "í"=>"i", "î"=>"i", "ï"=>"i", "ð"=>"d",
    "ñ"=>"n", "ò"=>"o", "ó"=>"o", "ô"=>"o", "õ"=>"o", "ö"=>"o", "ø"=>"o",
    "ù"=>"u", "ú"=>"u", "û"=>"u", "ü"=>"u", "ý"=>"y", "þ"=>"th", "ÿ"=>"y",
    "Ā"=>"A", "ā"=>"a", "Ă"=>"A", "ă"=>"a", "Ą"=>"A", "ą"=>"a", "Ć"=>"C",
    "ć"=>"c", "Ĉ"=>"C", "ĉ"=>"c", "Ċ"=>"C", "ċ"=>"c", "Č"=>"C", "č"=>"c",
    "Ď"=>"D", "ď"=>"d", "Đ"=>"D", "đ"=>"d", "Ē"=>"E", "ē"=>"e", "Ĕ"=>"E",
    "ĕ"=>"e", "Ė"=>"E", "ė"=>"e", "Ę"=>"E", "ę"=>"e", "Ě"=>"E", "ě"=>"e",
    "Ĝ"=>"G", "ĝ"=>"g", "Ğ"=>"G", "ğ"=>"g", "Ġ"=>"G", "ġ"=>"g", "Ģ"=>"G",
    "ģ"=>"g", "Ĥ"=>"H", "ĥ"=>"h", "Ħ"=>"H", "ħ"=>"h", "Ĩ"=>"I", "ĩ"=>"i",
    "Ī"=>"I", "ī"=>"i", "Ĭ"=>"I", "ĭ"=>"i", "Į"=>"I", "į"=>"i", "İ"=>"I",
    "ı"=>"i", "Ĳ"=>"IJ", "ĳ"=>"ij", "Ĵ"=>"J", "ĵ"=>"j", "Ķ"=>"K", "ķ"=>"k",
    "ĸ"=>"k", "Ĺ"=>"L", "ĺ"=>"l", "Ļ"=>"L", "ļ"=>"l", "Ľ"=>"L", "ľ"=>"l",
    "Ŀ"=>"L", "ŀ"=>"l", "Ł"=>"L", "ł"=>"l", "Ń"=>"N", "ń"=>"n", "Ņ"=>"N",
    "ņ"=>"n", "Ň"=>"N", "ň"=>"n", "ŉ"=>"'n", "Ŋ"=>"NG", "ŋ"=>"ng",
    "Ō"=>"O", "ō"=>"o", "Ŏ"=>"O", "ŏ"=>"o", "Ő"=>"O", "ő"=>"o", "Œ"=>"OE",
    "œ"=>"oe", "Ŕ"=>"R", "ŕ"=>"r", "Ŗ"=>"R", "ŗ"=>"r", "Ř"=>"R", "ř"=>"r",
    "Ś"=>"S", "ś"=>"s", "Ŝ"=>"S", "ŝ"=>"s", "Ş"=>"S", "ş"=>"s", "Š"=>"S",
    "š"=>"s", "Ţ"=>"T", "ţ"=>"t", "Ť"=>"T", "ť"=>"t", "Ŧ"=>"T", "ŧ"=>"t",
    "Ũ"=>"U", "ũ"=>"u", "Ū"=>"U", "ū"=>"u", "Ŭ"=>"U", "ŭ"=>"u", "Ů"=>"U",
    "ů"=>"u", "Ű"=>"U", "ű"=>"u", "Ų"=>"U", "ų"=>"u", "Ŵ"=>"W", "ŵ"=>"w",
    "Ŷ"=>"Y", "ŷ"=>"y", "Ÿ"=>"Y", "Ź"=>"Z", "ź"=>"z", "Ż"=>"Z", "ż"=>"z",
    "Ž"=>"Z", "ž"=>"z"
  }.freeze

  def self.normalize(string)
    string = string.downcase
    string = string.unicode_normalize!
    string
  rescue Encoding::CompatibilityError
    string
  end

  def self.normalize!(string)
    string.downcase!
    string.unicode_normalize!
  rescue Encoding::CompatibilityError
  end

  def transliterate(string)
    string.gsub(/[^\x00-\x7f]/u) { |char| approximations[char] || char }
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
  
  def search(query, dictionary: nil, prefix: :last, normalization: nil)
    exact_search = Runestone::WebSearch.parse(query, prefix: prefix)
    typo_search = exact_search.typos
    syn_search = typo_search.synonymize
    
    tsqueries = [exact_search, typo_search, syn_search].map(&:to_s).uniq.map do |q|
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