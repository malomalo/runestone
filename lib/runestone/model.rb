class Runestone::Model < ActiveRecord::Base

  self.table_name = :runestones

  attr_accessor :highlights
  
  belongs_to :record, polymorphic: true
  
  def self.highlight(records, query, prefix: nil)
    return [] if records.empty?
    
    binds = []
    records.each do |record|
      binds += get_binds(record.data, record.record_type.constantize.highlights(dictionary: records.first.dictionary))
    end

    hlites = binds.uniq

    newbinds = []
    binds.each_with_index do |b|
      newbinds << hlites.index(b)
    end
    binds = newbinds

    hlites = get_highlights(hlites, query, prefix: prefix, dictionary: records.first.dictionary)

    binds.map! { |x| hlites[x] }

    records.each do |record|
      record.highlights = highlight_data(
        record.data,
        binds,
        record.record_type.constantize.highlights
      )
    end
  end
  
  def self.highlight_data(data, hlights, indexes)
    str = {}
    indexes.each do |key, value|
      next unless data[key]

      if data[key].is_a?(Hash)
        str[key] = highlight_data(data[key], hlights, indexes[key])
      elsif data[key].is_a?(Array)
        str[key] = data[key].map { |i|
          if i.is_a?(Hash)
            highlight_data(i, hlights, indexes[key])
          else
            hlights.shift
          end
        }
      else
        str[key] = hlights.shift
      end
    end
    str
  end

  def self.get_highlights(words, query, prefix: nil, dictionary: nil)
    dictionary ||= Runestone.dictionary
    
    query = Arel::Nodes::TSQuery.new(Runestone::WebSearch.parse(query).prefix(prefix).typos.synonymize.to_s, language: dictionary).to_sql
    connection.exec_query(<<-SQL).cast_values
      SELECT ts_headline(#{connection.quote(dictionary)}, words, #{query}, 'ShortWord=2')
      FROM unnest(ARRAY[ #{words.map{ |t| connection.quote(t) }.join(', ')} ]::varchar[]) AS words
    SQL
  end
  
  def self.get_binds(hash, highlight)
    rt = []
    highlight.each do |k, v|
      next unless hash[k]

      if hash[k].is_a?(Hash)
        rt += get_binds(hash[k], highlight[k])
      elsif hash[k].is_a?(Array)
        hash[k].each do |i|
          if i.is_a?(Hash)
            rt += get_binds(i, highlight[k])
          else
            rt += i.is_a?(Array) ? i : [i]
          end
        end
      else
        rt << hash[k].to_s
      end
    end
    rt
  end

end
