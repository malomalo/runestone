require 'test_helper'

class OrderTest < ActiveSupport::TestCase

  schema do
    create_table :addresses, id: :uuid, force: :cascade do |t|
      t.string  "name"
      t.string  "metadata"
      t.uuid    "property_id"
    end
  end
  
  class Address < ActiveRecord::Base
    runestone do
      index 'name'
      attribute(:name)
    end
  end

  test 'smaller documents come first' do
    a2 = Address.create(name: 'a big square')
    a1 = Address.create(name: 'Square')
    a3 = Address.create(name: 'Squareit')

    query = Runestone::Model.search('square')
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'square'), 16) AS rank0,
        ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'square:*'), 16) AS rank1
      FROM "runestones"
      WHERE
        "runestones"."vector" @@ to_tsquery('runestone', 'square:*')
      ORDER BY rank0 DESC, rank1 DESC
    SQL
    
    assert_equal(query.map(&:record).map(&:name), [
      'Square',
      'a big square',
      'Squareit'
    ])
  end

  

end
