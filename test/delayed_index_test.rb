require 'test_helper'

class DelayedIndexingTest < ActiveSupport::TestCase

  schema do
    create_table :regions, id: :uuid, force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.boolean   "pooblic",              default: true
    end
  end
  

  class Region < ActiveRecord::Base
    include GlobalID::Identification
  
    runestone runner: :active_job do
      index 'name'
      attribute(:name)
    end
  end
  
  GlobalID.app = :default
  
  test 'runestone index on create' do
    region = assert_no_difference 'Runestone::Model.count' do
      assert_no_sql('INSERT INTO "runestones"') do
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
      'DelayedIndexingTest::Region', region.id,
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
    
    assert_no_sql('UPDATE "runestones"') do
      region.update!(name: 'New region name')
    end

    job = assert_enqueued_with(
      job: Runestone::IndexingJob,
      args: [region, :delayed_update_runestones!, [[:default, :runestone]]],
      queue: 'runestone_indexing'
    )

    job.perform_now

    assert_equal([[
      'DelayedIndexingTest::Region', region.id,
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
