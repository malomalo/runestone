require 'test_helper'

class WebSearchTest < ActiveSupport::TestCase

  test '::parse' do
    assert_equal "the & fat & rats:*", Runestone::WebSearch.parse('The fat rats').to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab').to_s
    # assert_equal "(sad <-> cat) | (fat <-> rat)", TS.websearch_to_tsquery('"sad cat" || "fat rat"')
    assert_equal "signal & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"').to_s
  end
  
  test '::parse(query, prefix: :all)' do
    assert_equal "the:* & fat:* & rats:*", Runestone::WebSearch.parse('The fat rats', prefix: :all).to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab', prefix: :all).to_s
    # assert_equal "(sad <-> cat) | (fat <-> rat)", TS.websearch_to_tsquery('"sad cat" || "fat rat"')
    assert_equal "signal:* & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"', prefix: :all).to_s
  end
  
  test '::parse(query, prefix: :last)' do
    assert_equal "the & fat & rats:*", Runestone::WebSearch.parse('The fat rats', prefix: :last).to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab', prefix: :last).to_s
    # assert_equal "(sad <-> cat) | (fat <-> rat)", TS.websearch_to_tsquery('"sad cat" || "fat rat"')
    assert_equal "signal & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"', prefix: :last).to_s
  end
  
  test '::parse(query, prefix: :none)' do
    assert_equal "the & fat & rats", Runestone::WebSearch.parse('The fat rats', prefix: :none).to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab', prefix: :none).to_s
    # assert_equal "(sad <-> cat) | (fat <-> rat)", TS.websearch_to_tsquery('"sad cat" || "fat rat"')
    assert_equal "signal & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"', prefix: :none).to_s
  end
  
  test '::parse(weird query, prefix: :none)' do
    assert_equal "supernovae <-> stars", Runestone::WebSearch.parse('"supernovae stars', prefix: :none).to_s
    assert_equal "signal", Runestone::WebSearch.parse('signal -', prefix: :none).to_s
    assert_equal "signal", Runestone::WebSearch.parse('signal -"', prefix: :none).to_s
    assert_equal "signal", Runestone::WebSearch.parse('signal -""', prefix: :none).to_s
  end

end