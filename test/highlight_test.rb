require 'test_helper'

class HighlightTest < ActiveSupport::TestCase

  schema do
    create_table :addresses, id: :uuid, force: :cascade do |t|
      t.string  "name"
      t.string  "metadata"
      t.uuid    "property_id"
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

  test '::highlights(query)' do
    Property.create(name: 'Empire state building', addresses: [Address.create(name: 'address uno')])
    Property.create(name: 'Big state building', addresses: [Address.create(name: 'address of state duo')])
    
    tsmodels = Runestone::Model.search('state')
    Runestone::Model.highlight(tsmodels, 'state')
    assert_equal([
      { "name"=>"address of <b>state</b> duo" },
      {
        "name"=>"Big <b>state</b> building",
        "addresses"=> [{"name"=>"address of <b>state</b> duo"}]
      },
      {
        "name"=>"Empire <b>state</b> building",
        "addresses"=> [{"name"=>"address uno"}]
      },

    ], tsmodels.map(&:highlights))
  end
  
  test '::highlights(query) with an accent in the result' do
    Property.create(name: 'Émpire state building', addresses: [Address.create(name: 'address uno')])
    Property.create(name: 'Big state building', addresses: [Address.create(name: 'addréss of state duo')])
    
    tsmodels = Runestone::Model.search('empire')
    Runestone::Model.highlight(tsmodels, 'empire')
    assert_equal([
      {
        "name"=>"<b>Émpire</b> state building",
        "addresses"=>[ {"name"=>"address uno"} ]
      }
    ], tsmodels.map(&:highlights))

    tsmodels = Runestone::Model.search('address')
    Runestone::Model.highlight(tsmodels, 'address')
    assert_equal([
      {"name"=>"<b>address</b> uno"},
      {"name"=>"<b>addréss</b> of state duo"},
      {"addresses"=>[{"name"=>"<b>address</b> uno"}], "name"=>"Émpire state building"},
      {"addresses"=>[{"name"=>"<b>addréss</b> of state duo"}], "name"=>"Big state building"}
    ], tsmodels.map(&:highlights))
  end
  
end
