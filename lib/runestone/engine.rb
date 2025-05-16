# frozen_string_literal: true

class Runestone::Engine < Rails::Engine
  config.runestone = ActiveSupport::OrderedOptions.new

  initializer :runestone do |app|
    ActiveSupport.on_load(:active_record) do
      require 'active_record/connection_adapters/postgresql/schema_dumper'
      ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.prepend(Runestone::PsqlSchemaDumper)
      ActiveRecord::Tasks::DatabaseTasks.migrations_paths << File.expand_path('../../../db/migrate', __FILE__)
    end
  end
  
  initializer "runestone.set_configs" do |app|
    options = app.config.runestone

    Runestone.runner = options.runner if options.runner
    Runestone.dictionary = options.dictionary if options.dictionary
    Runestone.normalization = options.normalization if options.normalization
    Runestone.job_queue = options.job_queue if options.job_queue
    Runestone.typo_tolerances = options.typo_tolerances if options.typo_tolerances
  end
end