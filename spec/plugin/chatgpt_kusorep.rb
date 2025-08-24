# frozen_string_literal: true

require 'json'
require_relative '../spec_helper'
require_relative '../../lib/plugin/chatgpt_kusorep'

RSpec.describe ChatGPTKusorep do
  subject(:plugin) { build_plugin(described_class) }

  let(:logger) { instance_double('Logger') }
  let(:options) { {} }
  let(:data) { build_event(text: 'kusorep テストメッセージ') }
  let(:matcher) { ['kusorep テストメッセージ', 'テストメッセージ'] }

  before do
    allow(plugin).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe '#kusorep_create' do
    it 'creates a Kusorep and sends the response' do
      allow(plugin).to receive(:send_message).and_return('クソリプの例')

      expect(data).to receive(:say).with(text: 'クソリプの例')
      plugin.kusorep_create(data, matcher)
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:send_message).and_raise(StandardError.new('エラー発生'))

      expect(data).to receive(:say).with(text: 'エラーが発生しました: エラー発生')
      plugin.kusorep_create(data, matcher)
    end
  end
end
