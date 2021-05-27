module Runestone::PsqlSchemaDumper

  def extensions(stream)
    super(stream)
    stream.puts <<-RB
  ## Install the default dictionary for Runestone in the database
  execute <<-SQL
    CREATE TEXT SEARCH CONFIGURATION runestone (COPY = simple);
    ALTER TEXT SEARCH CONFIGURATION runestone
      ALTER MAPPING FOR hword, hword_part, word
      WITH unaccent, simple;
  SQL
    RB
    stream
  end
  
end