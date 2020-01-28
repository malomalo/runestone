class CreateRunestoneTables < ActiveRecord::Migration[6.0]

  def change
    enable_extension 'pgcrypto'
    enable_extension 'pg_trgm'
    enable_extension 'fuzzystrmatch'

    create_table :runestones, id: :uuid do |t|
      t.belongs_to  :record, type: :uuid, polymorphic: true, null: false
      t.string      :name
      t.string      :dictionary
      t.jsonb       :data,    null: false
      t.tsvector    :vector,  null: false
    end

    add_index :runestones, [:record_type, :record_id, :name, :dictionary], unique: true, name: 'index_runestones_for_uniqueness'
    add_index :runestones, :vector, using: :gin

    execute <<-SQL
      CREATE TABLE runestone_corpus ( word varchar, CONSTRAINT word UNIQUE(word) );

      CREATE INDEX runestone_corpus_trgm_idx ON runestone_corpus USING GIN (word gin_trgm_ops);

      CREATE TEXT SEARCH CONFIGURATION simple_unaccent (COPY = simple);
      ALTER TEXT SEARCH CONFIGURATION simple_unaccent
        ALTER MAPPING FOR hword, hword_part, word
        WITH unaccent, simple;
    SQL
  end

end
