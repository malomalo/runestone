module ActiveRecord::SchemaSetup
  
  def self.included(base)
    base.extend ClassMethods
    base.class_eval do
      set_callback(:setup, :before) do
        if !self.class.class_variable_defined?(:@@suite_setup_run)
          configuration = {
            adapter:  "postgresql",
            database: "uuid-types-test",
            encoding: "utf8"
          }.stringify_keys

          ActiveRecord::Base.establish_connection(configuration)

          db_tasks = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(ActiveRecord::Base.connection_db_config)
          db_tasks.drop
          db_tasks.create

          ActiveRecord::Migration.suppress_messages do
            CreateRunestoneTables.migrate :up

            if self.class.class_variable_defined?(:@@schema)
              ActiveRecord::Schema.define(&self.class.class_variable_get(:@@schema))
              ActiveRecord::Migration.execute("SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'").each_row do |row|
                ActiveRecord::Migration.execute("ALTER SEQUENCE #{row[0]} RESTART WITH #{rand(50_000)}")
              end
            end
          end
        end
        self.class.class_variable_set(:@@suite_setup_run, true)
      end
    end
  end

  module ClassMethods
    def schema(&block)
      self.class_variable_set(:@@schema, block)
    end
  end

end
