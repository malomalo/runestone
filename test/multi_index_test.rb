require 'test_helper'

class MultiIndexTest < ActiveSupport::TestCase
  
  test 'simple index' do
    address = assert_difference 'Runestone::Model.count', 2 do
      assert_sql(/setweight\(to_tsvector\('english', 'empire state building'\), 'A'\)/, /setweight\(to_tsvector\('russian', 'эмпайр-стейт-билдинг'\), 'A'\)/) do
        Building.create(name_en: 'Empire State Building', name_ru: 'Эмпайр-Стейт-Билдинг')
      end
    end
    
    assert_equal([
      [
        'Building', address.id,
        nil, 'english',
        {"name" => "Empire State Building"},
        "'build':3A 'empir':1A 'state':2A"
      ],
      [
        'Building', address.id,
        nil, 'russian',
        {"name" => "Эмпайр-Стейт-Билдинг"},
        "'билдинг':4A 'стейт':3A 'эмпайр':2A 'эмпайр-стейт-билдинг':1A"
      ],
    ], address.runestones.map { |rs|
      [
        rs.record_type, rs.record_id,
        rs.name, rs.dictionary,
        rs.data,
        rs.vector
      ]
    })
    
    query = Runestone::Model.search('empire')
    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('runestone', 'empire:*')) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('runestone', 'empire:*')
      ORDER BY rank0 DESC
    SQL
    
    query = Runestone::Model.search('empire', dictionary: 'english')
    assert_sql(<<~SQL, query.to_sql)
      SELECT
        "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('english', 'empire:*')) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('english', 'empire:*')
      AND "runestones"."dictionary" = 'english'
      ORDER BY rank0 DESC
    SQL
    
    query = Runestone::Model.search('Эмпайр', dictionary: 'russian')
    assert_sql(<<~SQL, query.to_sql)
      SELECT "runestones".*, ts_rank_cd("runestones"."vector", to_tsquery('russian', 'эмпайр:*')) AS rank0
      FROM "runestones"
      WHERE "runestones"."vector" @@ to_tsquery('russian', 'эмпайр:*')
      AND "runestones"."dictionary" = 'russian'
      ORDER BY rank0 DESC
    SQL
  end
  
  test 'empty index' do
    address = assert_difference 'Runestone::Model.count', 1 do
      Address.create(name: nil)
    end

    assert_equal([[
      'Address', address.id,
      {},
      ""
    ]], address.runestones.map { |rs|
      [
        rs.record_type,
        rs.record_id,
        rs.data,
        rs.vector
      ]
    })
  end

  test 'complex index' do
    property = assert_difference 'Runestone::Model.count', 3 do
      Property.create(name: 'Property name', addresses: [
        Address.create(name: 'Address 1'),
        Address.create(name: 'Address 2')
      ])
    end

    assert_equal([[
      'Property', property.id,
      {
        "name"=>"Property name",
        "addresses"=>[
          { "id" => property.addresses.first.id, "name" => "Address 1" },
          { "id" => property.addresses.last.id,  "name" => "Address 2" }
        ]
      },
      "'1':4C '2':6C 'address':3C,5C 'name':2A 'property':1A"
    ]], property.runestones.map { |rs|
      [
        rs.record_type,
        rs.record_id,
        rs.data,
        rs.vector
      ]
    })
  end

  test 'index gets created on Model.create' do
    address = assert_difference 'Runestone::Model.count', 1 do
      Address.create(name: 'Address name')
    end
  end

  test 'index gets updated on Model.create' do
    address = Address.create(name: 'Address name')
    assert_no_difference 'Runestone::Model.count' do
      address.update!(name: 'Address name two')
    end

    assert_equal([[
      'Address', address.id,
      {"name" => "Address name two"},
      "'address':1A 'name':2A 'two':3A"
    ]], address.runestones.map { |rs|
      [
        rs.record_type,
        rs.record_id,
        rs.data,
        rs.vector
      ]
    })
  end

  test 'index gets deleted on Model.destroy' do
    address = Address.create(name: 'Address name')
    assert_difference 'Runestone::Model.count', -1 do
      address.destroy!
    end
  end

  test 'reindex! deleted removed records' do
    a1 = Address.create(name: 'one')
    a2 = Address.create(name: 'two')

    assert_no_difference 'Runestone::Model.count' do
      a2.delete
    end

    assert_difference 'Runestone::Model.count', -1 do
      Address.reindex!
    end
  end

  test 'reindex! updates runestones on outdated indexes' do
    address = Address.create(name: 'one')
    address.update_columns(name: 'two')

    assert_equal(["'one':1A"], address.runestones.map(&:vector))
    assert_no_difference 'Runestone::Model.count' do
      Address.reindex!
    end
    assert_equal(["'two':1A"], address.runestones.map { |rs| rs.reload.vector })
  end

  test 'reindex! creates index if not there' do
    address = Address.create(name: 'one')
    address.runestones.each(&:delete)

    assert_equal 0, address.reload.runestones.size
    assert_difference 'Runestone::Model.count', 1 do
      Address.reindex!
    end
    assert_equal(["'one':1A"], address.reload.runestones.map(&:vector))
  end
  
end
