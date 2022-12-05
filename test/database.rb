GlobalID.app = 'TestApp'

module H
  def extensions(stream)
    stream
  end
end

class SchemaHelper
  include H
  include Runestone::PsqlSchemaDumper
end

task = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new({
  'adapter' => 'postgresql',
  'database' => "arel-extensions-test"
})
task.drop
task.create

ActiveRecord::Base.establish_connection({
  adapter:  "postgresql",
  database: "arel-extensions-test",
  encoding: "utf8"
})

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Schema.define do
    enable_extension 'pgcrypto'
    enable_extension 'pg_trgm'
    enable_extension 'unaccent'
    enable_extension 'fuzzystrmatch'

    create_table :addresses, id: :uuid, force: :cascade do |t|
      t.string  "name"
      t.uuid    "property_id"
    end
    
    create_table :properties, id: :uuid, force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table :regions, id: :uuid, force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table :buildings, id: :uuid, force: :cascade do |t|
      t.string   "name_en",              limit: 255
      t.string   "name_ru",              limit: 255
    end

    create_table :runestones, id: :uuid, force: :cascade do |t|
      t.string    :record_type,     null: false
      t.uuid      :record_id,        null: false
      t.string    :name
      t.string    :dictionary
      t.jsonb     :data,      null: false
      t.tsvector  :vector,    null: false
    end

    add_index :runestones, [:record_type, :record_id, :name, :dictionary], unique: true, name: 'index_runestones_for_uniqueness'
    add_index :runestones, :vector, using: :gin

    execute <<-SQL
      CREATE TABLE runestone_corpus ( word varchar, CONSTRAINT word UNIQUE(word) );

      CREATE INDEX runestone_corpus_trgm_idx ON runestone_corpus USING GIN (word gin_trgm_ops);
    SQL
    
    execute(SchemaHelper.new.extensions(StringIO.new).string.gsub(/\A.*\n.*\n/, '').gsub(/.*\Z/, ''))
  end
end

class Address < ActiveRecord::Base
  
  belongs_to :property

  runestone do
    index 'name'

    attribute(:name)
  end

end

class Region < ActiveRecord::Base
  
  include GlobalID::Identification
  
  runestone runner: :active_job do
    index 'name'

    attribute(:name)
  end
  
end

class Property < ActiveRecord::Base
  
  has_many :addresses

  runestone do
    index :name
    index 'addresses.name', weight: 3

    attribute(:name)
    attribute(:addresses) { addresses.map{ |a| a&.attributes&.slice('id', 'name') } }
  end

end

class Building < ActiveRecord::Base
  
  runestone dictionary: 'english' do
    index :name

    attribute(:name) { name_en }
  end
  
  runestone dictionary: 'russian' do
    index :name

    attribute(:name) { name_ru }
  end

end