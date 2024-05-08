module Runestone::ActiveRecord
  module RelationMethods
  
    def ts_query(query, dictionary: nil)
      dictionary ||= Runestone.dictionary
    
      if query.is_a?(Arel::Nodes::TSQuery)
        query
      else
        Arel::Nodes::TSQuery.new(query, language: dictionary)
      end
    end

    def ts_vector(column_name, dictionary: nil)
      # if column_name.is_a?(String) || column_name.is_a?(Symbol)
      #   column = columns_hash[column_name.to_s]
      #   if column.type == :tsvector
      #     arel_table[column.name]
      #   else
      #     Arel::Nodes::TSVector.new(arel_table[column.name], language)
      #   end
      # else
      #   column_name
      # end
      Runestone::Model.arel_table[:vector]
    end

    def ts_match(vector, query, dictionary: nil)
      Arel::Nodes::TSMatch.new(
        ts_vector(vector, dictionary: dictionary),
        ts_query(query, dictionary: dictionary)
      )
    end

    def ts_rank(vector, query, dictionary: nil)
      Arel::Nodes::TSRank.new(
        ts_vector(vector, dictionary: dictionary),
        ts_query(query, dictionary: dictionary)
      )
    end

    def ts_rank_cd(vector, query, dictionary: nil, normalization: nil)
      normalization ||= Runestone.normalization
      
      Arel::Nodes::TSRankCD.new(
        ts_vector(vector, dictionary: dictionary),
        ts_query(query, dictionary: dictionary),
        normalization
      )
    end

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
        q.joins(:runestones).where(ts_match(Runestone::Model.arel_table['vector'], tsqueries.last, dictionary: dictionary))
      end

      q = q.where(dictionary: dictionary) if dictionary
        
      q.order(
        *tsqueries.each_with_index.map { |q, i| Arel::Nodes::Descending.new(Arel::Nodes::SqlLiteral.new("rank#{i}")) }
      )
    end
    
  end
end