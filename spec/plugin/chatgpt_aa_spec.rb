# frozen_string_literal: true

require 'json'
require_relative '../spec_helper'
require_relative '../../lib/plugin/chatgpt_aa'

RSpec.describe ChatGPTAA do
  subject(:plugin) { build_plugin(described_class) }

  let(:logger) { instance_double('Logger') }
  let(:options) { {} }
  let(:data) { build_event(text: 'aa テスト') }
  let(:matcher) { ['aa テスト', 'テスト'] }

  before do
    allow(plugin).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(plugin).to receive(:send_message).and_return("```\nAAの例\n```")
  end

  describe '#aa_create' do
    it 'creates an AA and sends the response' do
      expect(data).to receive(:say).with(text: "```\nAAの例\n```")
      plugin.aa_create(data, matcher)
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:send_message).and_raise(StandardError.new('エラー発生'))
      expect(data).to receive(:say).with(text: 'エラーが発生しました: エラー発生')
      plugin.aa_create(data, matcher)
    end
  end
end
