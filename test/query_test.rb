require 'test_helper'

class QueryTest < ActiveSupport::TestCase

  test '::search(query)' do
    query = Runestone::Model.search('seaerch for this')

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch & for & this:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'seaerch & for & this:*')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search(query) normalizes Unicode strings' do
    query = Runestone::Model.search("the search for \u0065\u0301")

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'the & search & for & \u00e9:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'the & search & for & \u00e9:*')
      ORDER BY rank0 DESC
    SQL
  end
  
  test "::search(query with ')" do
    query = Runestone::Model.search("seaerch for ' this")
    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch & for & this:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'seaerch & for & this:*')
      ORDER BY rank0 DESC
    SQL
    
    query = Runestone::Model.search("seaerch for james' map")
    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch & for & james & map:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'seaerch & for & james & map:*')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search(query, prefix: :all)' do
    query = Runestone::Model.search('seaerch for this', prefix: :all)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch:* & for:* & this:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'seaerch:* & for:* & this:*')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search(query, prefix: :none)' do
    query = Runestone::Model.search('search for this', prefix: :none)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'search & for & this'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'search & for & this')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search(query, prefix: :last)' do
    query = Runestone::Model.search('search for this', prefix: :last)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'search & for & this:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'search & for & this:*')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search("my token | token")' do
    query = Runestone::Model.search('my search | your token')

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(my & search:*) | (your & token:*)'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', '(my & search:*) | (your & token:*)')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search("token | token", prefix: :none)' do
    query = Runestone::Model.search('my search | your token', prefix: :none)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(my & search) | (your & token)'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', '(my & search) | (your & token)')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search("token | token", prefix: :all)' do
    query = Runestone::Model.search('my search | your token', prefix: :all)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(my:* & search:*) | (your:* & token:*)'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', '(my:* & search:*) | (your:* & token:*)')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search("token | token", prefix: :last)' do
    query = Runestone::Model.search('my search | your token', prefix: :last)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(my & search:*) | (your & token:*)'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', '(my & search:*) | (your & token:*)')
      ORDER BY rank0 DESC
    SQL
  end
  
  test '::search(query).limit(N)' do
    query = Runestone::Model.search('seaerch for this').limit(10)

    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch & for & this:*'), 16) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'seaerch & for & this:*')
      ORDER BY rank0 DESC
      LIMIT 10
    SQL
  end
  
  test 'Model::search(query)' do
    query = Property.search('seaerch for this')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "properties".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch & for & this:*'), 16) AS rank0
      FROM "properties"
      INNER JOIN "runestones"
        ON "runestones"."record_type" = 'Property'
        AND "runestones"."record_id" = "properties"."id"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', 'seaerch & for & this:*')
      ORDER BY rank0 DESC
    SQL
  end
  
  test 'Model::search(query) with misspelling in query' do
    Runestone::Corpus.add('search')
    query = Property.search('seaerch for this')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "properties".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'seaerch & for & this:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(seaerch | search) & for & this:*'), 16) AS rank1
      FROM "properties"
      INNER JOIN "runestones"
        ON "runestones"."record_type" = 'Property'
        AND "runestones"."record_id" = "properties"."id"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(seaerch | search) & for & this:*')
      ORDER BY
        rank0 DESC,
        rank1 DESC
    SQL
  end
  
  test 'Model::search( | query) with misspelling in query' do
    Runestone::Corpus.add('search', 'this')
    query = Property.search('seaerch for this | for thiss')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "properties".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(seaerch & for & this:*) | (for & thiss:*)'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '((seaerch | search) & for & this:*) | (for & (thiss:* | this))'), 16) AS rank1
      FROM "properties"
      INNER JOIN "runestones"
        ON "runestones"."record_type" = 'Property'
        AND "runestones"."record_id" = "properties"."id"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '((seaerch | search) & for & this:*) | (for & (thiss:* | this))')
      ORDER BY
        rank0 DESC,
        rank1 DESC
    SQL
  end
  
  test "::typos with special chars" do
    Runestone::Corpus.add(*%w{avenue aveneue avenue)})
    
    words = "AVENUE AV AVE AVN AVEN AVENU AVNUE".split(/\s+/)
    words.each do |word|
      Runestone.add_synonym(word, *words.select { |w| w != word })
    end

    assert_sql(<<~SQL, Runestone::Model.search('avenue').to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'avenue:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'avenue:* | aveneue'), 16) AS rank1,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'avenue:* | aveneue | av | ave | avn | aven | avenu | avnue'), 16) AS rank2
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', 'avenue:* | aveneue | av | ave | avn | aven | avenu | avnue')
      ORDER BY
        rank0 DESC,
        rank1 DESC,
        rank2 DESC
    SQL
  end

end
