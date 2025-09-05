# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/plugin/chatgpt_reverse'

RSpec.describe ChatGPTReverse do
  subject(:plugin) { build_plugin(described_class) }

  let(:logger) { test_logger }
  let(:options) { {} }
  let(:data) { build_event(text: '対義語 とびだせどうぶつの森') }
  let(:matcher) { ['対義語 とびだせどうぶつの森', 'とびだせどうぶつの森'] }

  before do
    plugin.instance_variable_set(:@logger, logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe '#initialize' do
    it 'sets up the handler for antonym creation' do
      expect(plugin).to have_handler(/^対義語[[:space:]](.*)$/)
    end
  end

  describe '#antonym_create' do
    context 'when ChatGPT responds successfully' do
      let(:chatgpt_response) { 'ひっこめ人間の砂漠' }

      before do
        allow(data).to receive(:chatgpt).and_return(chatgpt_response)
        allow(data).to receive(:say)
      end

      it 'sends the correct messages to ChatGPT' do
        expected_messages = [
          { role: 'system', content: '質問を単語毎に分解して対義語を返してください。一例として「とびだせどうぶつの森」は「ひっこめ人間の砂漠」になります' },
          { role: 'user', content: 'とびだせどうぶつの森' },
          { role: 'assistant', content: 'ひっこめ人間の砂漠' },
          { role: 'user', content: 'とびだせどうぶつの森' }
        ]

        plugin.antonym_create(data, matcher)

        expect(data).to have_received(:chatgpt).with(expected_messages)
      end

      it 'logs the received message' do
        plugin.antonym_create(data, matcher)

        expect(logger).to have_received(:info).with('Received message for antonym creation: とびだせどうぶつの森')
      end

      it 'logs the ChatGPT response' do
        plugin.antonym_create(data, matcher)

        expect(logger).to have_received(:info).with("ChatGPT antonym response: #{chatgpt_response}")
      end

      it 'sends the response back to the channel' do
        plugin.antonym_create(data, matcher)

        expect(data).to have_received(:say).with(text: chatgpt_response)
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'API connection failed' }
      let(:error) { StandardError.new(error_message) }

      before do
        allow(data).to receive(:chatgpt).and_raise(error)
        allow(data).to receive(:say)
      end

      it 'logs the error' do
        plugin.antonym_create(data, matcher)

        expect(logger).to have_received(:error).with("Error in antonym_create: #{error_message}")
      end

      it 'sends an error message to the channel' do
        plugin.antonym_create(data, matcher)

        expect(data).to have_received(:say).with(text: "エラーが発生しました: #{error_message}")
      end
    end

    context 'with different input words' do
      let(:word) { '明るい' }
      let(:expected_response) { '暗い' }
      let(:different_matcher) { ['対義語 明るい', '明るい'] }

      before do
        allow(data).to receive(:chatgpt).and_return(expected_response)
        allow(data).to receive(:say)
        plugin.instance_variable_set(:@logger, logger)
      end

      it 'processes different words correctly' do
        plugin.antonym_create(data, different_matcher)

        expected_messages = [
          { role: 'system', content: '質問を単語毎に分解して対義語を返してください。一例として「とびだせどうぶつの森」は「ひっこめ人間の砂漠」になります' },
          { role: 'user', content: 'とびだせどうぶつの森' },
          { role: 'assistant', content: 'ひっこめ人間の砂漠' },
          { role: 'user', content: '明るい' }
        ]

        expect(data).to have_received(:chatgpt).with(expected_messages)
        expect(data).to have_received(:say).with(text: expected_response)
      end
    end
  end
end
