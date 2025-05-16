# frozen_string_literal: true

class Runestone::IndexingJob < ActiveJob::Base
  queue_as { Runestone.job_queue }
  
  def perform(record, indexing_method, *args)
    record.public_send(indexing_method, *args)
  end
  
end