module Runestone::PsqlSchemaDumper

  def extensions(stream)
    super(stream)
    stream.puts <<-RB
  ## Install the default dictionary for Runestone in the database
  execute <<-SQL
    CREATE EXTENSION IF NOT EXISTS rparser;
    CREATE TEXT SEARCH CONFIGURATION runestone (PARSER = rparser);
    ALTER TEXT SEARCH CONFIGURATION runestone
    ALTER MAPPING FOR
      asciiword, word, numword, asciihword, hword, numhword, hword_asciipart,
      hword_part, hword_numpart, email, protocol, url, host, url_path, file, sfloat,
      float, int, uint, version, tag, entity, symbol
    WITH unaccent, simple;
  SQL
    RB
    stream
  end
  
end