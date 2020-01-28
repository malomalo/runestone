class Runestone::IndexingJob < ActiveJob::Base
  queue_as { Runestone.job_queue }
  
  def perform(record, indexing_method)
    record.public_send(indexing_method)
  end
  
end