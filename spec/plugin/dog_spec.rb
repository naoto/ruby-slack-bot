# frozen_string_literal: true

require 'json'
require_relative '../spec_helper'
require_relative '../../lib/plugin/base'
require_relative '../../lib/plugin/dog'

RSpec.describe Dog do
  subject(:plugin) { build_plugin(described_class) }

  describe 'handler registration' do
    it 'registers a handler for /^dog$/i' do
      expect(plugin).to have_handler(/^dog$/i)
    end
  end

  describe 'dog command processing' do
    let(:expected_url) { 'https://example.com/dog.jpg' }
    let(:data) { build_event(text: 'dog') }
    let(:captured_output) { [] }

    before do
      stub_http_get(
        'https://dog.ceo/api/breeds/image/random',
        body: { message: expected_url, status: 'succcess' }
      )
      allow(data).to receive(:say) { |text:| captured_output << text }
    end

    context 'when the message is "dog"' do
      it 'fetches an image URL via message method' do
        plugin.message(data, nil)
        expect(captured_output.first).to eq(expected_url)
      end

      it 'works through the registered block' do
        pattern = plugin.keyword_method_list.first
        expect('dog').to match(pattern[:regex])

        pattern[:block].call(data:, matcher: nil)
        expect(captured_output.first).to eq(expected_url)
      end
    end
  end
end
