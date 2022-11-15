require 'active_support/concern'

module Runestone::ActiveRecord
  module BaseMethods

    extend ActiveSupport::Concern
  
    included do
      class_attribute :runestone_settings, instance_accessor: true
    end
  
    class_methods do

      def runestone(name: :default, dictionary: nil, runner: nil, &block)
        runner ||= Runestone.runner
        dictionary  ||= Runestone.dictionary
        
        if self.runestone_settings.nil?
          self.runestone_settings = {}

          class_eval do
            has_many :runestones, class_name: 'Runestone::Model', as: :record, dependent: :destroy
            
            case runner
            when :active_job
              after_commit :create_runestones, on: :create
              after_commit :update_runestones, on: :update
            else
              after_create :create_runestones!
              after_update :update_runestones!
            end
          end
        end
        
        self.runestone_settings[name] ||= []
        self.runestone_settings[name] << Runestone::Settings.new(base_class.name, name: name, dictionary: dictionary, &block)
      end

      def reindex!
        conn = Runestone::Model.connection
        model_table = conn.quote_table_name(table_name)
        
        conn.execute(<<-SQL.gsub("\n", ' ').gsub(/\s+/, " ").strip)
          DELETE FROM runestones
          USING runestones AS t2
          LEFT OUTER JOIN #{model_table} ON
            t2.record_type = #{conn.quote(base_class.name)}
            AND t2.record_id = #{model_table}.id
          WHERE runestones.record_type = #{conn.quote(base_class.name)}
            AND runestones.record_id = t2.record_id
            AND #{model_table}.id IS NULL;
        SQL

        find_each(&:update_runestones!)
      end

      def highlights(name: :default, dictionary: nil)
        dictionary ||= Runestone.dictionary

        rsettings = self.runestone_settings[name].find { |s| s.dictionary.to_s == dictionary.to_s }
        @highlights ||= highlight_indexes(rsettings.indexes.values.flatten.map{ |i| i.to_s.split('.') })
      end

      def highlight_indexes(indexes)
        str = {}
        indexes.sort.group_by { |i| i[0] }.each do |key, value|
          value.each(&:shift)
          value.reject!(&:empty?)
          str[key] = value.empty? ? true : highlight_indexes(value)
        end
        str
      end

    end

    def create_runestones
      Runestone::IndexingJob.perform_later(self, :create_runestones!)
    end
    
    def create_runestones!
      conn = Runestone::Model.connection
      self.runestone_settings.each do |index_name, settings|
        settings.each do |setting|
          rdata = setting.extract_attributes(self)

          ts_column_names = %w(record_type record_id name dictionary data vector).map { |name| conn.quote_column_name(name) }
          ts_values = [
            conn.quote(conn.send(:type_map).lookup('varchar').serialize(self.class.base_class.name)),
            conn.quote(conn.send(:type_map).lookup('uuid').serialize(id)),
            index_name == :default ? 'NULL' : conn.quote(conn.send(:type_map).lookup('varchar').serialize(index_name.to_s)),
            conn.quote(conn.send(:type_map).lookup('varchar').serialize(setting.dictionary)),
            conn.quote(conn.send(:type_map).lookup('jsonb').serialize(rdata)),
            setting.vectorize(rdata).join(' || ')
          ]
          conn.execute(<<-SQL.gsub("\n", ' ').gsub(/\s+/, " ").strip)
            INSERT INTO #{Runestone::Model.quoted_table_name} (#{ts_column_names.join(",")})
            VALUES (#{ts_values.join(',')})
          SQL

          Runestone::Corpus.add(*setting.corpus(rdata))
        end
      end
    end
    
    def update_runestones
      Runestone::IndexingJob.preform_later(self, :update_runestones!)
    end
    
    def update_runestones!
      conn = Runestone::Model.connection
      self.runestone_settings.each do |index_name, settings|
        settings.each do |setting|
          rdata = setting.extract_attributes(self)

          if conn.execute(<<-SQL.gsub("\n", ' ').gsub(/\s+/, " ").strip).cmd_tuples == 0
              UPDATE #{Runestone::Model.quoted_table_name}
              SET
                data = #{conn.quote(conn.send(:type_map).lookup('jsonb').serialize(rdata))},
                vector = #{setting.vectorize(rdata).join(' || ')}
              WHERE record_type = #{conn.quote(conn.send(:type_map).lookup('varchar').serialize(self.class.base_class.name))}
              AND record_id = #{conn.quote(conn.send(:type_map).lookup('integer').serialize(id))}
              AND name #{index_name == :default ? 'IS NULL' : "= " + conn.quote(conn.send(:type_map).lookup('integer').serialize(index_name))}
              AND dictionary = #{conn.quote(conn.send(:type_map).lookup('integer').serialize(setting.dictionary))}
              SQL
            create_runestones!
          else
            Runestone::Corpus.add(*setting.corpus(rdata))
          end

        end
      end
    end

  end
end