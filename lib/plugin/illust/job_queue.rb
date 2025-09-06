# frozen_string_literal: true

class IllustJobQueue
  def initialize(max_size:, logger:)
    @queue = SizedQueue.new(max_size)
    @logger = logger
    @contents = []
    @mutex = Mutex.new
  end

  def enqueue(job)
    @logger.info "Enqueueing job: prompt=#{job[:prompt]}, seed=#{job[:seed]}"
    @queue.push(job, true)
    @mutex.synchronize { @contents << job }
    true
  rescue ThreadError
    @logger.warn 'Queue is full, rejecting job'
    false
  end

  def dequeue
    job = @queue.pop
    @mutex.synchronize { @contents.delete(job) }
    job
  end

  def size
    @queue.size
  end

  def contents
    @mutex.synchronize { @contents.dup }
  end
end
