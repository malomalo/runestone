class CreateRunestoneTables < ActiveRecord::Migration[6.0]

  def change
    enable_extension 'pgcrypto'
    enable_extension 'pg_trgm'
    enable_extension 'fuzzystrmatch'
    enable_extension 'unaccent'

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

      CREATE EXTENSION IF NOT EXISTS rparser;
      CREATE TEXT SEARCH CONFIGURATION runestone (PARSER = rparser);
      ALTER TEXT SEARCH CONFIGURATION runestone
      ALTER MAPPING FOR
        asciiword, word, numword, asciihword, hword, numhword, hword_asciipart,
        hword_part, hword_numpart, email, protocol, url, host, url_path, file, sfloat,
        float, int, uint, version, tag, entity, symbol
      WITH unaccent, simple;
    SQL
  end

end
