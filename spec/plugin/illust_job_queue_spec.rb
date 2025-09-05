# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/bot/data'
require_relative '../../lib/plugin/illust/job_queue'

RSpec.describe IllustJobQueue do
  let(:logger) { test_logger }
  let(:max_size) { 5 }
  let(:queue) { IllustJobQueue.new(max_size: max_size, logger: logger) }

  describe '#initialize' do
    it 'creates a queue with the specified max size' do
      expect(queue.size).to eq(0)
    end
  end

  describe '#enqueue' do
    let(:job) { { prompt: 'test prompt', seed: 42 } }

    context 'when queue is not full' do
      it 'successfully enqueues a job' do
        result = queue.enqueue(job)
        
        expect(result).to be true
        expect(queue.size).to eq(1)
        expect(logger).to have_received(:info).with(match(/Enqueueing job: prompt=test prompt, seed=42/))
      end
    end

    context 'when queue is full' do
      before do
        max_size.times { queue.enqueue({ prompt: 'filler', seed: 1 }) }
      end

      it 'rejects the job and returns false' do
        result = queue.enqueue(job)
        
        expect(result).to be false
        expect(queue.size).to eq(max_size)
        expect(logger).to have_received(:warn).with('Queue is full, rejecting job')
      end
    end
  end

  describe '#dequeue' do
    let(:job1) { { prompt: 'job1', seed: 1 } }
    let(:job2) { { prompt: 'job2', seed: 2 } }

    before do
      queue.enqueue(job1)
      queue.enqueue(job2)
    end

    it 'returns jobs in FIFO order' do
      first_job = queue.dequeue
      expect(first_job).to eq(job1)
      expect(queue.size).to eq(1)
    end
  end

  describe '#contents' do
    let(:job1) { { prompt: 'job1', seed: 1 } }
    let(:job2) { { prompt: 'job2', seed: 2 } }

    before do
      queue.enqueue(job1)
      queue.enqueue(job2)
    end

    it 'returns a copy of the queue contents' do
      contents = queue.contents
      expect(contents).to eq([job1, job2])
      
      # Verify it's a copy, not the original
      contents.clear
      expect(queue.size).to eq(2)
    end
  end
end
