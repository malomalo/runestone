require 'test_helper'

class WebSearchTest < ActiveSupport::TestCase

  test '::parse' do
    assert_equal "the & fat & rats", Runestone::WebSearch.parse('The fat rats').to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab').to_s
    assert_equal "sad <-> cat | fat <-> rat", Runestone::WebSearch.parse('"sad cat" | "fat rat"').to_s
    assert_equal "signal & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"').to_s
  end
  
  test '::parse(weird query)' do
    assert_equal "supernovae <-> stars", Runestone::WebSearch.parse('"supernovae stars').to_s
    assert_equal "signal & \\-", Runestone::WebSearch.parse('signal -').to_s
    assert_equal "signal", Runestone::WebSearch.parse('signal -"').to_s
    assert_equal "signal", Runestone::WebSearch.parse('signal -""').to_s
    
    assert_equal "super & supernovae <-> stars", Runestone::WebSearch.parse('super "supernovae stars').to_s
    assert_equal "super & signal & \\-", Runestone::WebSearch.parse('super signal -').to_s
    assert_equal "super & signal", Runestone::WebSearch.parse('super signal -"').to_s
    assert_equal "super & signal", Runestone::WebSearch.parse('super signal -""').to_s
  end

end