require 'test_helper'

class PrefixTest < ActiveSupport::TestCase

  test '::prefix(:last)' do
    assert_equal "the & fat & rats:*", Runestone::WebSearch.parse('The fat rats').prefix(:last).to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab').prefix(:last).to_s
    assert_equal "sad <-> cat | fat <-> rat", Runestone::WebSearch.parse('"sad cat" | "fat rat"').prefix(:last).to_s
    assert_equal "signal & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"').prefix(:last).to_s
  end
  
  test '::parse(query, prefix: :all)' do
    assert_equal "the:* & fat:* & rats:*", Runestone::WebSearch.parse('The fat rats').prefix(:all).to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab').prefix(:all).to_s
    assert_equal "sad <-> cat | fat <-> rat", Runestone::WebSearch.parse('"sad cat" | "fat rat"').prefix(:all).to_s
    assert_equal "signal:* & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"').prefix(:all).to_s
  end

  test '::parse(query, prefix: :none)' do
    assert_equal "the & fat & rats", Runestone::WebSearch.parse('The fat rats').prefix(:none).to_s
    assert_equal "supernovae <-> stars & !crab", Runestone::WebSearch.parse('"supernovae stars" -crab').prefix(:none).to_s
    assert_equal "sad <-> cat | fat <-> rat", Runestone::WebSearch.parse('"sad cat" | "fat rat"').prefix(:none).to_s
    assert_equal "signal & !(segmentation <-> fault)", Runestone::WebSearch.parse('signal -"segmentation fault"').prefix(:none).to_s
  end

  test '::parse(weird query, prefix: :none)' do
    assert_equal "signal:*", Runestone::WebSearch.parse('signal').prefix(:last).to_s
    assert_equal "super & supernovae <-> stars", Runestone::WebSearch.parse('super "supernovae stars').prefix(:last).to_s
    assert_equal "super & signal & \\-:*", Runestone::WebSearch.parse('super signal -').prefix(:last).to_s
    assert_equal "super & signal:*", Runestone::WebSearch.parse('super signal -"').prefix(:last).to_s
    assert_equal "super & signal:*", Runestone::WebSearch.parse('super signal -""').prefix(:last).to_s

    assert_equal "signal:*", Runestone::WebSearch.parse('signal').prefix(:all).to_s
    assert_equal "super:* & supernovae <-> stars", Runestone::WebSearch.parse('super "supernovae stars').prefix(:all).to_s
    assert_equal "super:* & signal:* & \\-:*", Runestone::WebSearch.parse('super signal -').prefix(:all).to_s
    assert_equal "super:* & signal:*", Runestone::WebSearch.parse('super signal -"').prefix(:all).to_s
    assert_equal "super:* & signal:*", Runestone::WebSearch.parse('super signal -""').prefix(:all).to_s

    assert_equal "signal", Runestone::WebSearch.parse('signal').prefix(:none).to_s
    assert_equal "super & supernovae <-> stars", Runestone::WebSearch.parse('super "supernovae stars').prefix(:none).to_s
    assert_equal "super & signal & \\-", Runestone::WebSearch.parse('super signal -').prefix(:none).to_s
    assert_equal "super & signal", Runestone::WebSearch.parse('super signal -"').prefix(:none).to_s
    assert_equal "super & signal", Runestone::WebSearch.parse('super signal -""').prefix(:none).to_s
  end

end