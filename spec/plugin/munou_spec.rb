# frozen_string_literal: true

require 'json'
require_relative '../spec_helper'
require_relative '../../lib/plugin/base'
require_relative '../../lib/plugin/munou'

RSpec.describe Munou do
  subject(:plugin) { build_plugin(described_class) }

  describe 'handler registration' do
    it 'registers a handler for munou chat pattern' do
      expect(plugin).to have_handler(/^(無能|むのう)[[:space:]](.*)$/)
    end

    it 'registers a handler for search pattern' do
      expect(plugin).to have_handler(/^(.*)調べて$/)
    end
  end

  describe '#munou_chat' do
    let(:text) { '無能 こんにちは' }
    let(:data) { build_event(text: text) }
    let(:matcher) { text.match(/^(無能|むのう)[[:space:]](.*)$/) }
    let(:mock_response) do
      { message: { content: 'こんにちは！何かお手伝いできることはありますか？' } }
    end

    before do
      allow(plugin).to receive(:send_message).and_return(mock_response)
    end

    it 'sends message to ollama with correct context' do
      plugin.munou_chat(data, matcher)
      
      expect(plugin).to have_received(:send_message).with(
        context: 'こんにちは',
        history: []
      )
    end

    it 'responds with the generated content' do
      expect(data).to receive(:say).with(text: 'こんにちは！何かお手伝いできることはありますか？')
      
      plugin.munou_chat(data, matcher)
    end

    it 'adds user message to history' do
      plugin.munou_chat(data, matcher)
      
      expect(plugin.instance_variable_get(:@history)).to include(
        { role: 'user', content: 'こんにちは' }
      )
    end

    it 'adds assistant response to history' do
      plugin.munou_chat(data, matcher)
      
      expect(plugin.instance_variable_get(:@history)).to include(
        { role: 'assistant', content: 'こんにちは！何かお手伝いできることはありますか？' }
      )
    end

    context 'when an error occurs' do
      before do
        allow(plugin).to receive(:send_message).and_raise(StandardError, 'Connection failed')
      end

      it 'handles error gracefully' do
        expect(data).to receive(:say).with(text: 'エラーが発生しました: Connection failed')
        
        plugin.munou_chat(data, matcher)
      end

      it 'logs the error' do
        expect(plugin.logger).to receive(:error).with('Error in munou_chat: Connection failed')
        
        plugin.munou_chat(data, matcher)
      end
    end
  end

  describe '#munou_search' do
    let(:text) { 'Ruby調べて' }
    let(:data) { build_event(text: text) }
    let(:matcher) { text.match(/^(.*)調べて$/) }
    let(:search_result) { 'Rubyはプログラミング言語です。' }

    before do
      allow(plugin).to receive(:search).and_return(search_result)
    end

    it 'searches with correct word' do
      plugin.munou_search(data, matcher)
      
      expect(plugin).to have_received(:search).with('Ruby')
    end

    it 'responds with search result' do
      expect(data).to receive(:say).with(text: search_result)
      
      plugin.munou_search(data, matcher)
    end

    context 'when search fails' do
      before do
        allow(plugin).to receive(:search).and_raise(StandardError, 'Search API failed')
      end

      it 'handles error gracefully' do
        expect(data).to receive(:say).with(text: 'エラーが発生しました: Search API failed')
        
        plugin.munou_search(data, matcher)
      end

      it 'logs the error' do
        expect(plugin.logger).to receive(:error).with('Error in munou_search: Search API failed')
        
        plugin.munou_search(data, matcher)
      end
    end
  end

  describe '#clear_history' do
    it 'clears the conversation history' do
      plugin.instance_variable_set(:@history, [{ role: 'user', content: 'test' }])
      
      plugin.clear_history
      
      expect(plugin.instance_variable_get(:@history)).to be_empty
    end
  end

  describe '#history_size' do
    it 'returns the current history size' do
      history = [
        { role: 'user', content: 'message1' },
        { role: 'assistant', content: 'response1' }
      ]
      plugin.instance_variable_set(:@history, history)
      
      expect(plugin.history_size).to eq(2)
    end
  end

  describe 'history management' do
    it 'limits history size to MAX_HISTORY_SIZE' do
      # Fill history beyond limit
      (described_class::MAX_HISTORY_SIZE + 2).times do |i|
        plugin.instance_variable_get(:@history) << { role: 'user', content: "message#{i}" }
      end

      # Trigger history limit
      plugin.send(:limit_history_size)
      
      expect(plugin.history_size).to eq(described_class::MAX_HISTORY_SIZE)
    end
  end
end
