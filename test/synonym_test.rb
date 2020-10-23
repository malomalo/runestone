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
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce:*')) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)')) AS rank1
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

    assert_equal "(supernovae:* | (super <1> novae))", Runestone::WebSearch.parse('supernovae').synonymize.to_s
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
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce:*')) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)')) AS rank1
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
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & !spruce')) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & !spruce')) AS rank1
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
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce')) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & spruce')) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & spruce')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end
  
  test '::synonym expanded for misspellings' do
    Runestone::Corpus.add(*%w{17 seventeen spruce pine plne})
    Runestone.add_synonyms({
      '17' => %w(17th seventeen seventeenth),
      'spruce' => %w(pine)
    })
    query = Runestone::Model.search('17 spruce')
    
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '17 & spruce:*')) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)')) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '(17 | 17th | seventeen | seventeenth) & (spruce:* | pine)')
      ORDER BY rank0 DESC, rank1 DESC
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
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'one & hundred & spruce:*')) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', '((one & hundred | 100) & spruce:* | (one & hundred | one hundy) & spruce:*)')) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', '((one & hundred | 100) & spruce:* | (one & hundred | one hundy) & spruce:*)')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
  end

end