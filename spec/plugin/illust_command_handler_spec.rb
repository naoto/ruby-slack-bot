# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/plugin/illust/command_handler'

RSpec.describe IllustCommandHandler do
  let(:job_queue) { double('IllustJobQueue') }
  let(:translator) { double('IllustTranslator') }
  let(:logger) { test_logger }
  let(:handler) { IllustCommandHandler.new(job_queue: job_queue, translator: translator, logger: logger) }
  let(:data) { double('Data') }

  before do
    allow(job_queue).to receive(:enqueue).and_return(true)
    allow(job_queue).to receive(:size).and_return(0)
    allow(job_queue).to receive(:contents).and_return([])
    allow(data).to receive(:say)
    allow(data).to receive(:get_parent_url).and_return([nil, nil])
  end

  describe '#handle_japanese_illust' do
    let(:prompt) { '猫' }
    let(:translated_prompt) { 'cat' }

    before do
      allow(translator).to receive(:translate_to_english).and_return(translated_prompt)
    end

    it 'translates the prompt and enqueues the job' do
      handler.handle_japanese_illust(data, prompt)

      expect(translator).to have_received(:translate_to_english).with(prompt)
      expect(job_queue).to have_received(:enqueue) do |job|
        expect(job[:prompt]).to eq(translated_prompt)
        expect(job[:org_prompt]).to eq(prompt)
        expect(job[:data]).to eq(data)
      end
    end

    context 'when translation fails' do
      before do
        allow(translator).to receive(:translate_to_english).and_raise(StandardError, 'translation error')
      end

      it 'handles the error gracefully' do
        handler.handle_japanese_illust(data, prompt)

        expect(data).to have_received(:say).with(text: 'エラーが発生しました: translation error')
        expect(logger).to have_received(:error).with('Error in handle_japanese_illust: translation error')
      end
    end
  end

  describe '#handle_english_illust' do
    let(:prompt) { 'cat' }

    it 'enqueues the job without translation' do
      handler.handle_english_illust(data, prompt)

      expect(job_queue).to have_received(:enqueue) do |job|
        expect(job[:prompt]).to eq(prompt)
        expect(job[:org_prompt]).to eq(prompt)
        expect(job[:data]).to eq(data)
      end
    end
  end

  describe '#handle_img2img' do
    let(:prompt) { '猫' }
    let(:translated_prompt) { 'cat' }
    let(:image_url) { 'http://example.com/image.png' }
    let(:thread_ts) { 'thread123' }

    before do
      allow(data).to receive(:get_parent_url).and_return([image_url, thread_ts])
      allow(translator).to receive(:translate_to_english).and_return(translated_prompt)
    end

    context 'when parent image exists' do
      it 'translates the prompt and enqueues the img2img job' do
        handler.handle_img2img(data, prompt)

        expect(translator).to have_received(:translate_to_english).with(prompt)
        expect(job_queue).to have_received(:enqueue) do |job|
          expect(job[:prompt]).to eq(translated_prompt)
          expect(job[:org_prompt]).to eq(prompt)
          expect(job[:url]).to eq(image_url)
          expect(job[:ts]).to eq(thread_ts)
          expect(job[:data]).to eq(data)
        end
      end
    end

    context 'when no parent image exists' do
      before do
        allow(data).to receive(:get_parent_url).and_return([nil, nil])
        allow(data).to receive(:thread_ts).and_return('current_thread')
        allow(data).to receive(:ts).and_return('current_ts')
      end

      it 'sends an error message' do
        handler.handle_img2img(data, prompt)

        expect(data).to have_received(:say).with(
          text: "元画像のURLが取得できません。スレッド内で実行してください。",
          thread_ts: 'current_thread'
        )
      end
    end
  end

  describe '#handle_queue_status' do
    before do
      allow(job_queue).to receive(:size).and_return(3)
      allow(job_queue).to receive(:contents).and_return(['job1', 'job2', 'job3'])
    end

    it 'reports the current queue status' do
      handler.handle_queue_status(data)

      expect(data).to have_received(:say).with(text: '現在のイラスト生成キューの長さは 3 です。')
      expect(data).to have_received(:say).with(text: "job1\njob2\njob3")
    end

    context 'when queue is empty' do
      before do
        allow(job_queue).to receive(:size).and_return(0)
        allow(job_queue).to receive(:contents).and_return([])
      end

      it 'reports empty queue' do
        handler.handle_queue_status(data)

        expect(data).to have_received(:say).with(text: '現在のイラスト生成キューの長さは 0 です。')
        expect(data).to_not have_received(:say).with(text: match(/job/))
      end
    end

    context 'when an error occurs' do
      before do
        allow(job_queue).to receive(:size).and_raise(StandardError, 'queue error')
      end

      it 'handles the error gracefully' do
        handler.handle_queue_status(data)

        expect(data).to have_received(:say).with(text: 'エラーが発生しました: queue error')
        expect(logger).to have_received(:error).with('Error in handle_queue_status: queue error')
      end
    end
  end
end
