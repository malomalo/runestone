require 'test_helper'

class HighlightTest < ActiveSupport::TestCase

  test '::highlights(query)' do
    Property.create(name: 'Empire state building', addresses: [Address.create(name: 'address uno')])
    Property.create(name: 'Big state building', addresses: [Address.create(name: 'address of state duo')])
    
    tsmodels = Runestone::Model.search('state')
    Runestone::Model.highlight(tsmodels, 'state')
    assert_equal([
      {
        "name"=>"Big <b>state</b> building",
        "addresses"=> [{"name"=>"address of <b>state</b> duo"}]
      },
      {
        "name"=>"Empire <b>state</b> building",
        "addresses"=> [{"name"=>"address uno"}]
      },
      {
        "name"=>"address of <b>state</b> duo"
      }
    ], tsmodels.map(&:highlights))
  end
  
end
