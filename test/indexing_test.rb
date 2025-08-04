require 'test_helper'

class IndexingTest < ActiveSupport::TestCase
  
  schema do
    create_table :addresses, id: :uuid, force: :cascade do |t|
      t.string  "name"
      t.string  "metadata"
      t.uuid    "property_id"
    end

    create_table :buildings, id: :uuid, force: :cascade do |t|
      t.string   "name_en",              limit: 255
      t.string   "name_ru",              limit: 255
      t.string   "name_es",              limit: 255
    end

    create_table :people, id: :uuid, force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.boolean   "pooblic",              default: true
    end

    create_table :properties, id: :uuid, force: :cascade do |t|
      t.string  "name",                 limit: 255
      t.string  "metadata"
    end
  end
  
  class Address < ActiveRecord::Base
    belongs_to :property

    runestone do
      index 'name'
      attribute(:name)
    end
  end

  class Property < ActiveRecord::Base
    has_many :addresses, autosave: true

    runestone do
      index :name
      index 'addresses.name', weight: 3

      attribute(:name)
      attribute(:addresses) { addresses.map{ |a| a&.attributes&.slice('id', 'name') } }
    end
  end
  
  class Person < ActiveRecord::Base
    runestone do
      index 'name'
    
      attribute :name, on: -> () { pooblic } do
        name
      end
    end
  end
  
  class Building < ActiveRecord::Base
    
    runestone do
      index :name_eu, :name_ru
      
      attributes(:name_en, :name_ru)
    end
    
    runestone dictionary: 'english' do
      index :name

      attribute(:name, on: :name_en_changed?) { name_en }
    end
  
    runestone dictionary: 'russian' do
      index :name

      attribute(:name, on: :name_ru_changed?) { name_ru }
    end
    
    runestone dictionary: 'spanish' do
      index :name

      attribute(:name) { name_es }
    end
  end
  
  test 'runestone index' do
    address = assert_difference 'Runestone::Model.count', 1 do
      assert_sql(/setweight\(to_tsvector\('runestone', 'address name'\), 'A'\)/) do
        Address.create(name: 'Address name')
      end
    end

    assert_equal([[
      'IndexingTest::Address', address.id,
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
      'IndexingTest::Address', address.id,
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
      'IndexingTest::Property', property.id,
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

    assert_equal("on\u00e9", address.reload.runestones.first.data['name'])
    assert_equal("'on\u00e9':1A", address.reload.runestones.first.vector)

    address = Address.create(name: "on\u0065\u0301 two three four five")

    assert_equal("on\u00e9 two three four five", address.reload.runestones.first.data['name'])
    assert_equal("'five':5A 'four':4A 'one':1A 'three':3A 'two':2A", address.reload.runestones.first.vector)
  end

  test 'index gets created on Model.create' do
    assert_difference 'Runestone::Model.count', 1 do
      Address.create(name: 'Address name')
    end
    
    assert_corpus('address', 'name')
  end

  test 'index gets updated on Model.update' do
    address = Address.create(name: 'Address name')
    assert_no_difference 'Runestone::Model.count' do
      address.update!(name: 'Address name two')
    end

    assert_equal([[
      'IndexingTest::Address', address.id,
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

  test 'index doesnt update on Model.update when updates dont affect index (column for attribute, depends on itself)' do
    address = Address.create(name: 'Address name')
    assert_no_difference 'Runestone::Model.count' do
      assert_no_sql("UPDATE runestones SET data") do
        address.update!(metadata: 'extra info not used in index')
      end
    end

    assert_equal([[
      'IndexingTest::Address', address.id,
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
    
    assert_corpus('address', 'name')
  end

  test 'index doesnt update on Model.update when updates dont affect index (proc for attribute, depends on relation)' do
    property = Property.create(name: 'Property name', addresses: [
      Address.create(name: 'Address 1'),
      Address.create(name: 'Address 2')
    ])

    assert_no_difference 'Runestone::Model.count' do
      assert_no_sql("UPDATE runestones SET data") do
        property.update!(metadata: 'extra info not used in index')
      end
    end

    assert_equal([[
      'IndexingTest::Property', property.id,
      {"name"=>"Property name", "addresses"=>[
        {"id"=> property.addresses[0].id, "name"=>"Address 1"},
        {"id"=> property.addresses[1].id, "name"=>"Address 2"}
      ]},
      "'1':4C '2':6C 'address':3C,5C 'name':2A 'property':1A"
    ]], property.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })

    assert_corpus("1", "2", "address", "name", "property")
  end
  
  test 'index updates on Model.update when relation is load/changed (proc for attribute, depends on relation)' do
    property = Property.create(name: 'Property name', addresses: [
      Address.create(name: 'Address 1'),
      Address.create(name: 'Address 2')
    ])
    
    assert_no_difference 'Runestone::Model.count' do
      assert_sql("UPDATE runestones SET data") do
        property.addresses.first.name = 'Address rename 1'
        property.save
      end
    end

    assert_equal([[
      'IndexingTest::Property', property.id,
      {"name"=>"Property name", "addresses"=>[
        {"id"=> property.addresses[0].id, "name"=>"Address rename 1"},
        {"id"=> property.addresses[1].id, "name"=>"Address 2"}
      ]},
      "'1':5C '2':7C 'address':3C,6C 'name':2A 'property':1A 'rename':4C"
    ]], property.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })

    assert_corpus("1", "2", "address", "name", "property", "rename")
  end

  test 'index doesnt update on Model.update when updates dont affect index (block for attribute, depends on attribute)' do
    building = Building.create(name_en: 'name', name_ru: 'имя')
    
    assert_no_difference 'Runestone::Model.count' do
      assert_no_sql("UPDATE runestones SET data = '{\"name\":\"имя\"}") do
        building.update!(name_en: 'name 2')
      end
    end

    assert_equal([[
        'IndexingTest::Building', building.id,
        {"name"=>"name 2"},
        "'2':2A 'name':1A"
      ], [
        'IndexingTest::Building', building.id,
        {"name_en"=>"name 2", "name_ru"=>"имя"},
        "'имя':1A",
      ], [
        'IndexingTest::Building', building.id,
        {"name"=>"имя"},
        "'имя':1A"
      ], [
        'IndexingTest::Building', building.id,
        {},
        ""
      ]
    ], building.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
    
    assert_corpus('2', 'name', 'имя')
  end
  
  test 'index always updates when we there is no dependency' do
    building = Building.create(name_en: 'name', name_ru: 'имя', name_es: 'nombre')
    
    assert_no_difference 'Runestone::Model.count' do
      assert_sql("UPDATE runestones SET data = '{\"name\":\"nombre\"}") do
        building.update!(name_en: 'name 2')
      end
    end

    assert_equal([[
        'IndexingTest::Building', building.id,
        {"name"=>"name 2"},
        "'2':2A 'name':1A"
      ], [
        'IndexingTest::Building', building.id,
        {"name_en"=>"name 2", "name_ru"=>"имя"},
        "'имя':1A",
      ], [
        'IndexingTest::Building', building.id,
        {"name"=>"имя"},
        "'имя':1A"
      ], [
        'IndexingTest::Building', building.id,
        {"name"=>"nombre"},
        "'nombr':1A"
      ]
    ], building.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
    
    assert_corpus('2', 'name', 'nombre', 'имя')
  end
  
  test 'index doesnt update on Model.update when updates dont affect index (block for attribute, block for depends)' do
    record = Person.create(name: 'person')
    
    assert_no_difference 'Runestone::Model.count' do
      assert_no_sql("UPDATE runestones SET data") do
        record.update!(name: 'ghost', pooblic: false)
      end
    end

    assert_equal([[
        'IndexingTest::Person', record.id,
        {"name"=>"person"},
        "'person':1A"
      ]
    ], record.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
    
    assert_corpus('person')
  end
  
  test 'index updates on Model.update when updates affect index (block for attribute, block for depends)' do
    record = Person.create(name: 'person')
    
    assert_no_difference 'Runestone::Model.count' do
      assert_sql("UPDATE runestones SET data") do
        record.update!(name: 'physical', pooblic: true)
      end
    end

    assert_equal([[
        'IndexingTest::Person', record.id,
        {"name"=>"physical"},
        "'physical':1A"
      ]
    ], record.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
    
    assert_corpus('person', 'physical')
  end

  test 'index gets deleted on Model.destroy' do
    address = Address.create(name: 'Address name')
    assert_difference 'Runestone::Model.count', -1 do
      address.destroy!
    end
  end

  test 'reindex_runestones! deleted removed records' do
    a1 = Address.create(name: 'one')
    a2 = Address.create(name: 'two')

    assert_no_difference 'Runestone::Model.count' do
      a2.delete
    end

    assert_difference 'Runestone::Model.count', -1 do
      Address.reindex_runestones!
    end
  end

  test 'reindex_runestones! updates runestone on outdated indexes' do
    address = Address.create(name: 'one')
    address.update_columns(name: 'two')

    assert_equal(["'one':1A"], address.runestones.map(&:vector))
    assert_no_difference 'Runestone::Model.count' do
      Address.reindex_runestones!
    end
    assert_equal(["'two':1A"], address.runestones.map { |runestone| runestone.reload.vector })
  end

  test 'reindex_runestones! creates index if not there' do
    address = Address.create(name: 'one')
    address.runestones.each(&:delete)

    assert_equal 0, address.reload.runestones.size
    assert_difference 'Runestone::Model.count', 1 do
      Address.reindex_runestones!
    end
    assert_equal(["'one':1A"], address.reload.runestones.map(&:vector))
  end
  
  test "warning message when runestone can't compute dependency for attribute in index" do
    begin
      output = StringIO.new
      ActiveRecord::Base.logger = Logger.new(output, level: :warn)
      ActiveRecord::Base.logger.formatter = -> (a,b,c,d) { d }
    
      b = Building.create(name_en: 'name')
      assert_includes output.string, "\e[1m\e[31mWARNING\e[0m Runestone index on \"IndexingTest::Building\" can't determine when to update attribute \"name\", provide \"on:\" option to stop update when unnceessary"
    ensure
      ActiveRecord::Base.logger = nil
    end
  end
end
