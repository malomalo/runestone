require 'test_helper'

class DelayedIndexingTest < ActiveSupport::TestCase
  
  test 'simple_unaccent index' do
    region = assert_no_difference 'Runestone::Model.count' do
      assert_no_sql(/setweight\(to_tsvector\('simple_unaccent', 'address name'\), 'A'\)/) do
        Region.create(name: 'Region name')
      end
    end
    
    job = assert_enqueued_with(
      job: Runestone::IndexingJob,
      args: [region, :create_runestones!],
      queue: 'runestone_indexing'
    )
    
    job.perform_now

    assert_equal([[
      'Region', region.id,
      {"name" => "Region name"},
      "'name':2A 'region':1A"
    ]], region.runestones.map { |runestone|
      [
        runestone.record_type,
        runestone.record_id,
        runestone.data,
        runestone.vector
      ]
    })
  end
  
end
