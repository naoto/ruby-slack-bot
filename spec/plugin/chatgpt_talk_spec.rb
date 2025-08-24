# frozen_string_literal: true

require 'json'
require_relative '../spec_helper'
require_relative '../../lib/plugin/chatgpt_talk'

RSpec.describe ChatGPTTalk do
  subject(:plugin) { build_plugin(described_class) }

  let(:logger) { instance_double('Logger') }
  let(:options) { {} }
  let(:data) { build_event(text: 'なおぼっと テストメッセージ') }
  let(:matcher) { ['なおぼっと テストメッセージ', 'テストメッセージ'] }

  before do
    allow(plugin).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(Backup).to receive(:load_backup).and_return([])
    allow(Backup).to receive(:load_backup_job).and_return('あなたは高性能AIです。')
    allow(Backup).to receive(:backup).and_return(true)
  end

  describe '#message_talk' do
    it 'sends a message to ChatGPT and returns the response' do
      allow(plugin).to receive(:chatgpt).and_return('ChatGPTの応答')

      plugin.message_talk(data, matcher)

      expect(data).to have_received(:say).with(text: 'ChatGPTの応答')
      expect(plugin.instance_variable_get(:@message_history)).to include(
        { role: 'user', content: 'テストメッセージ' },
        { role: 'assistant', content: 'ChatGPTの応答' }
      )
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:chatgpt).and_raise(StandardError.new('エラー発生'))

      plugin.message_talk(data, matcher)

      expect(data).to have_received(:say).with(text: 'エラーが発生しました: エラー発生')
    end
  end

  describe '#job_display' do
    it 'displays the current job system prompt' do
      expect(data).to receive(:say).with(text: 'job あなたは高性能AIです。')
      plugin.job_display(data, matcher)
    end
  end

  describe '#job_set' do
    context 'when setting a new job' do
      let(:new_job) { '新しいシステムプロンプト' }

      before do
        matcher[1] = new_job
      end

      it 'sets the new job and confirms it' do
        expect(Backup).to receive(:backup_job).with(new_job, plugin.instance_variable_get(:@talk_job_system_file))
        expect(data).to receive(:say).with(text: "新しいシステムプロンプトを設定しました: #{new_job}")

        plugin.job_set(data, matcher)
      end
    end

    context 'when no job is provided' do
      before { matcher[1] = '' }

      it 'prompts for a valid job input' do
        expect(data).to receive(:say).with(text: 'システムプロンプトを設定するには、`job <内容>`と入力してください。')
        plugin.job_set(data, matcher)
      end
    end

    it 'handles errors gracefully' do
      allow(Backup).to receive(:backup_job).and_raise(StandardError.new('エラー発生'))

      plugin.job_set(data, matcher)

      expect(data).to have_received(:say).with(text: 'エラーが発生しました: エラー発生')
    end
  end

  describe '#job_reset' do
    it 'resets the job to the default system prompt' do
      expect(Backup).to receive(:backup_job).with('あなたは高性能AIです。', plugin.instance_variable_get(:@talk_job_system_file))
      expect(data).to receive(:say).with(text: 'システムプロンプトをリセットしました。')

      plugin.job_reset(data, matcher)

      expect(plugin.instance_variable_get(:@talk_system)).to eq('あなたは高性能AIです。')
    end

    it 'handles errors gracefully' do
      allow(Backup).to receive(:backup_job).and_raise(StandardError.new('エラー発生'))

      plugin.job_reset(data, matcher)

      expect(data).to have_received(:say).with(text: 'エラーが発生しました: エラー発生')
    end
  end

  describe '#talk_reset' do
    it 'resets the message history' do
      expect(data).to receive(:say).with(text: '会話履歴をリセットしました。')
      plugin.talk_reset(data, matcher)

      expect(plugin.instance_variable_get(:@message_history)).to eq([])
    end

    it 'handles errors gracefully' do
      allow(Backup).to receive(:backup).and_raise(StandardError.new('エラー発生'))

      plugin.talk_reset(data, matcher)

      expect(data).to have_received(:say).with(text: 'エラーが発生しました: エラー発生')
    end
  end
end
