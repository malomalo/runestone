require 'test_helper'

class SynonymTest < ActiveSupport::TestCase

  test '::synonyms' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce' => %w(pine)
    })

    query = Runestone::Model.search('17 spruce')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end
  
  test '::synonyms expanded to two words' do
    Runestone.add_synonyms({
      'supernovae' => ['super novae']
    })

    assert_equal "supernovae:* | super <1> novae", Runestone::WebSearch.parse('supernovae').synonymize.to_s
  end

  test '::synonyms are evaluated in lowercase' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 Spruce')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

  test '::not with synonyms' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 -spruce')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & !spruce'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & !spruce'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & !spruce')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

  test '::synonym in quotes' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 "spruce"')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & spruce'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & spruce')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end
  
  test '::synonym expanded for misspellings' do
    Runestone::Corpus.add(*%w{17 seventeen spruce pine})
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 sprice')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & sprice:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & (sprice:* | spruce)'), 16) AS rank1,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (sprice:* | spruce | pine)'), 16) AS rank2
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (sprice:* | spruce | pine)')
      ORDER BY rank0 DESC, rank1 DESC, rank2 DESC
    SQL
  end

  test '::synonym expanded for misspellings in multi word match' do
    Runestone::Corpus.add(*%w{17 seventeen bean spruce pine})
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce bean street' => "pine bean st"
    })
    query = Runestone::Model.search('17 sprice beat street')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & sprice & beat & street:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & (sprice | spruce) & (beat | bean) & street:*'), 16) AS rank1,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & ((sprice | spruce) & (beat | bean) & street:* | pine <1> bean <1> st)'), 16) AS rank2
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & ((sprice | spruce) & (beat | bean) & street:* | pine <1> bean <1> st)')
      ORDER BY rank0 DESC, rank1 DESC, rank2 DESC
    SQL
  end

  test '::synonym phrase substitution' do
    Runestone.add_synonyms({
      'one hundred' => ['100', 'one hundy']
    })
    query = Runestone::Model.search('one hundred spruce')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'one & hundred & spruce:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(one & hundred | 100 | one <1> hundy) & spruce:*'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(one & hundred | 100 | one <1> hundy) & spruce:*')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

  test '::synonyms in ors' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      '20' => %w(20th twenty),
      'spruce' => %w(pine)
    })

    query = Runestone::Model.search('17 spruce | 20 spruce')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce:* | 20 & spruce:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine) | (20 | 20th | twenty) & (spruce:* | pine)'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine) | (20 | 20th | twenty) & (spruce:* | pine)')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

  test '::synonyms expanded to two words in ors' do
    Runestone.add_synonyms({
      'supernovae' => ['super novae'],
      'micronovae' => ['micro novae']
    })

    assert_equal "supernovae:* | super <1> novae | micronovae:* | micro <1> novae", Runestone::WebSearch.parse('supernovae | micronovae').synonymize.to_s
  end

  test '::not with synonyms and ors' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      '20' => %w(20th twenty),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 -spruce | 20 -spruce')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & !spruce | 20 & !spruce'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & !spruce | (20 | 20th | twenty) & !spruce'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & !spruce | (20 | 20th | twenty) & !spruce')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

  test '::synonym in quotes with or' do
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      '20' => %w(20th twenty),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 "spruce" | 20 "spruce"')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce | 20 & spruce'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & spruce | (20 | 20th | twenty) & spruce'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & spruce | (20 | 20th | twenty) & spruce')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end
  
  test '::synonym phrase substitution of a phrase with a equal size phrase' do
    Runestone.add_synonyms({
      'one hundred' => ['100', 'one hundy'],
      'fourty' => ['40']
    })
    
    query = Runestone::Model.search('one hundred fourty spruce | one hundred fourty pine')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'one & hundred & fourty & spruce:* | one & hundred & fourty & pine:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(one & hundred | 100 | one <1> hundy) & (fourty | 40) & spruce:* | (one & hundred | 100 | one <1> hundy) & (fourty | 40) & pine:*'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(one & hundred | 100 | one <1> hundy) & (fourty | 40) & spruce:* | (one & hundred | 100 | one <1> hundy) & (fourty | 40) & pine:*')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

  test '::synonym phrase substitution of a phrase with a smaller phrase' do
    Runestone.add_synonyms({
      'one hun dred' => ['100', 'one hundy'],
      'fourty' => ['40']
    })
    
    query = Runestone::Model.search('one hun dred fourty spruce | one hun dred fourty pine')

    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'one & hun & dred & fourty & spruce:* | one & hun & dred & fourty & pine:*'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(one & hun & dred | 100 | one <1> hundy) & (fourty | 40) & spruce:* | (one & hun & dred | 100 | one <1> hundy) & (fourty | 40) & pine:*'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(one & hun & dred | 100 | one <1> hundy) & (fourty | 40) & spruce:* | (one & hun & dred | 100 | one <1> hundy) & (fourty | 40) & pine:*')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

end