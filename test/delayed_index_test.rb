require 'test_helper'

class DelayedIndexingTest < ActiveSupport::TestCase
  
  test 'runestone index on create' do
    region = assert_no_difference 'Runestone::Model.count' do
      assert_no_sql(/setweight\(to_tsvector\('runestone', 'address name'\), 'A'\)/) do
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
  
  test 'runestone index on update' do
    region = Region.create(name: 'Region name')
    perform_enqueued_jobs
    
    assert_no_difference 'Runestone::Model.count' do
      assert_no_sql(/setweight\(to_tsvector\('runestone', 'address name'\), 'A'\)/) do
        region.update!(name: 'New region name')
      end
    end

    job = assert_enqueued_with(
      job: Runestone::IndexingJob,
      args: [region, :delayed_update_runestones!, [[:default, :runestone]]],
      queue: 'runestone_indexing'
    )
    
    job.perform_now

    assert_equal([[
      'Region', region.id,
      {"name" => "New region name"},
      "'name':3A 'new':1A 'region':2A"
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
