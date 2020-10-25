require 'test_helper'

class OrderTest < ActiveSupport::TestCase

  test 'smaller documents come first' do
    a2 = Address.create(name: 'a big square')
    a1 = Address.create(name: 'Square')

    query = Runestone::Model.search('square')
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'square:*'), 16) AS rank0
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', 'square:*')
      ORDER BY rank0 DESC
    SQL
    
    assert_equal(query.map(&:record).map(&:name), [
      'Square',
      'a big square'
    ])
  end

  

end
