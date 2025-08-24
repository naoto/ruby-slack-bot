# frozen_string_literal: true

require 'json'
require_relative '../spec_helper'
require_relative '../../lib/plugin/chatgpt_bokete'

RSpec.describe ChatGPTBokete do
  subject(:plugin) { build_plugin(described_class) }

  let(:logger) { instance_double('Logger') }
  let(:options) { {} }
  let(:data) { build_event(text: 'bokete テストメッセージ') }
  let(:matcher) { ['bokete テストメッセージ', 'テストメッセージ'] }

  before do
    allow(plugin).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe '#bokete_create' do
    it 'creates a Bokete and sends the response' do
      allow(plugin).to receive(:send_message).and_return('Boketeの例')

      expect(data).to receive(:say).with(text: 'Boketeの例')
      plugin.bokete_create(data, matcher)
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:send_message).and_raise(StandardError.new('エラー発生'))

      expect(data).to receive(:say).with(text: 'エラーが発生しました: エラー発生')
      plugin.bokete_create(data, matcher)
    end
  end

  describe '#bokete_milkboy' do
    it 'creates a Milkboy Bokete and sends the response' do
      allow(plugin).to receive(:send_message).and_return('Milkboy Boketeの例')

      expect(data).to receive(:say).with(text: 'Milkboy Boketeの例')
      plugin.bokete_milkboy(data, matcher)
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:send_message).and_raise(StandardError.new('エラー発生'))

      expect(data).to receive(:say).with(text: 'エラーが発生しました: エラー発生')
      plugin.bokete_milkboy(data, matcher)
    end
  end

  describe '#bokete_coolpoko' do
    it 'creates a Coolpoko Bokete and sends the response' do
      allow(plugin).to receive(:send_message).and_return('Coolpoko Boketeの例')

      expect(data).to receive(:say).with(text: 'Coolpoko Boketeの例')
      plugin.bokete_coolpoko(data, matcher)
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:send_message).and_raise(StandardError.new('エラー発生'))

      expect(data).to receive(:say).with(text: 'エラーが発生しました: エラー発生')
      plugin.bokete_coolpoko(data, matcher)
    end
  end

  describe '#bokete_joyman' do
    it 'creates a Joyman Bokete and sends the response' do
      allow(plugin).to receive(:send_message).and_return('Joyman Boketeの例')

      expect(data).to receive(:say).with(text: 'Joyman Boketeの例')
      plugin.bokete_joyman(data, matcher)
    end

    it 'handles errors gracefully' do
      allow(plugin).to receive(:send_message).and_raise(StandardError.new('エラー発生'))

      expect(data).to receive(:say).with(text: 'エラーが発生しました: エラー発生')
      plugin.bokete_joyman(data, matcher)
    end
  end
end
