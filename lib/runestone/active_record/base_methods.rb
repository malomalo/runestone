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
              after_update { update_runestones!(changed_runestone_indexes) }
            end
          end
        end
        
        self.runestone_settings[name] ||= {}
        self.runestone_settings[name][dictionary.to_sym] = Runestone::Settings.new(base_class.name, name: name, dictionary: dictionary, &block)
      end

      def reindex_runestones!
        conn = Runestone::Model.connection
        model_table = conn.quote_table_name(table_name)
        
        conn.execute(<<-SQL)
          DELETE FROM runestones
          USING runestones AS t2
          LEFT OUTER JOIN #{model_table} ON
            t2.record_type = #{conn.quote(base_class.name)}
            AND t2.record_id = #{model_table}.id
          WHERE runestones.record_type = #{conn.quote(base_class.name)}
            AND runestones.record_id = t2.record_id
            AND #{model_table}.id IS NULL;
        SQL

        find_each { |r| r.reindex_runestones! }
      end

      def highlights(name: :default, dictionary: nil)
        dictionary ||= Runestone.dictionary

        rsettings = self.runestone_settings[name][dictionary.to_sym]
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
        settings.each do |dictionary, setting|
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
          conn.execute(<<-SQL)
            INSERT INTO #{Runestone::Model.quoted_table_name} (#{ts_column_names.join(",")})
            VALUES (#{ts_values.join(',')})
          SQL

          Runestone::Corpus.add(*setting.corpus(rdata))
        end
      end
    end
    
    def changed_runestone_indexes
      changed_indexes =[]
      runestone_settings.each do |name, value|
        value.each do |dictionary, setting|
          changed_indexes << setting if setting.changed?(self)
        end
      end
      
      changed_indexes
    end
    
    def update_runestones
      Runestone::IndexingJob.perform_later(self, :delayed_update_runestones!, changed_runestone_indexes.map { |s| [s.name, s.dictionary] })
    end
    
    def delayed_update_runestones!(indexes)
      update_runestones!(indexes.map { |name, dictionary| runestone_settings[name][dictionary] })
    end
    
    def update_runestones!(indexes = nil)
      if indexes.nil?
        indexes = runestone_settings.values.map(&:values).flatten
      end
      
      conn = Runestone::Model.connection
      indexes.each do |setting|
        rdata = setting.extract_attributes(self)

        if conn.execute(<<-SQL).cmd_tuples == 0
            UPDATE #{Runestone::Model.quoted_table_name}
            SET
              data = #{conn.quote(conn.send(:type_map).lookup('jsonb').serialize(rdata))},
              vector = #{setting.vectorize(rdata).join(' || ')}
            WHERE record_type = #{conn.quote(conn.send(:type_map).lookup('varchar').serialize(self.class.base_class.name))}
            AND record_id = #{conn.quote(conn.send(:type_map).lookup('integer').serialize(id))}
            AND name #{setting.name == :default ? 'IS NULL' : "= " + conn.quote(conn.send(:type_map).lookup('integer').serialize(setting.name))}
            AND dictionary = #{conn.quote(conn.send(:type_map).lookup('integer').serialize(setting.dictionary))}
            SQL
          create_runestones!
        else
          Runestone::Corpus.add(*setting.corpus(rdata))
        end

      end
    end
    alias reindex_runestones! update_runestones!

  end
end