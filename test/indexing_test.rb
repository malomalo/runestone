require 'test_helper'

class IndexingTest < ActiveSupport::TestCase
  
  test 'simple_unaccent index' do
    address = assert_difference 'Runestone::Model.count', 1 do
      assert_sql(/setweight\(to_tsvector\('simple_unaccent', 'address name'\), 'A'\)/) do
        Address.create(name: 'Address name')
      end
    end

    assert_equal([[
      'Address', address.id,
      {"name" => "Address name"},
      "'address':1A 'name':2A"
    ]], address.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
  end

  test 'empty index' do
    address = assert_difference 'Runestone::Model.count', 1 do
      Address.create(name: nil)
    end

    assert_equal([[
      'Address', address.id,
      {},
      ""
    ]], address.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
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
    ]], property.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
  end
  
  test 'index Unicode strings get normalized' do
    address = Address.create(name: "on\u0065\u0301")

    assert_equal(["'on\u00e9':1A"], address.reload.runestones.map(&:vector))
  end

  test 'index gets created on Model.create' do
    address = assert_difference 'Runestone::Model.count', 1 do
      Address.create(name: 'Address name')
    end
    
    assert_corpus('address', 'name')
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
    ]], address.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
    
    assert_corpus('address', 'name', 'two')
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

  test 'reindex! updates runestone on outdated indexes' do
    address = Address.create(name: 'one')
    address.update_columns(name: 'two')

    assert_equal(["'one':1A"], address.runestones.map(&:vector))
    assert_no_difference 'Runestone::Model.count' do
      Address.reindex!
    end
    assert_equal(["'two':1A"], address.runestones.map { |runestone| runestone.reload.vector })
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
