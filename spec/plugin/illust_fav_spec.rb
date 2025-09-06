# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/plugin/base'
require_relative '../../lib/plugin/illust_fav'

RSpec.describe IllustFav do
  let(:illust_server) { 'test-server.com' }
  let(:http_client) { double('HTTPClient') }
  let(:options) { { illust_server: illust_server, http_client: http_client } }

  subject(:plugin) { build_plugin(described_class, options: options) }

  before do
    ENV['ILLUST_SERVER'] = illust_server
  end

  describe 'initialization' do
    context 'when illust_server is not configured' do
      let(:options) { { http_client: http_client } }

      before do
        ENV.delete('ILLUST_SERVER')
      end

      it 'raises ArgumentError' do
        expect { build_plugin(described_class, options: options) }
          .to raise_error(ArgumentError, 'ILLUST_SERVER is not configured')
      end
    end

    context 'when configuration is valid' do
      it 'initializes successfully' do
        expect { plugin }.not_to raise_error
      end
    end
  end

  describe 'handler registration' do
    it 'registers a handler for emoji tags' do
      expect(plugin).to have_handler(/^(?:(?::.+:)(?:\s)?)+$/)
    end

    it 'registers a handler for tag listing' do
      expect(plugin).to have_handler(/^tag$/)
    end

    it 'registers a handler for tag counting' do
      expect(plugin).to have_handler(/^count[[:space:]]+(?:(?::.+:)(?:[[:space:]])?)+$/)
    end

    it 'registers a reaction handler for tagging' do
      expect(plugin.reaction_method_list).not_to be_empty
    end
  end

  describe '#get_tag_count' do
    let(:data) { build_event(text: 'count :cat: :dog:') }
    let(:matcher) { data.text.match(/^count[[:space:]]+(?:(?::.+:)(?:[[:space:]])?)+$/) }
    let(:cat_lines) { "image1.jpg\nimage2.jpg\nimage3.jpg" }
    let(:dog_lines) { "image2.jpg\nimage3.jpg\nimage4.jpg" }

    before do
      allow(http_client).to receive(:get).with("https://#{illust_server}/cat.txt")
                                         .and_return(double(code: 200, body: cat_lines))
      allow(http_client).to receive(:get).with("https://#{illust_server}/dog.txt")
                                         .and_return(double(code: 200, body: dog_lines))
    end

    it 'returns the count of common images' do
      expect(data).to receive(:say).with(text: 'count :cat: :dog:: 2')
      plugin.get_tag_count(data, matcher)
    end

    context 'when no common images exist' do
      let(:dog_lines) { "image5.jpg\nimage6.jpg" }

      it 'returns zero count' do
        expect(data).to receive(:say).with(text: 'count :cat: :dog:: 0')
        plugin.get_tag_count(data, matcher)
      end
    end

    context 'when API request fails' do
      before do
        allow(http_client).to receive(:get).with("https://#{illust_server}/cat.txt")
                                           .and_return(double(code: 404))
      end

      it 'logs warning and returns early' do
        expect(plugin.instance_variable_get(:@logger)).to receive(:warn)
        plugin.get_tag_count(data, matcher)
      end
    end
  end

  describe '#get_tag_list' do
    let(:data) { build_event(text: 'tag') }
    let(:tags) { %w[cat dog bird] }

    context 'when tags exist' do
      before do
        allow(http_client).to receive(:get).with("https://#{illust_server}/tag")
                                           .and_return(double(code: 200, body: tags.to_json))
      end

      it 'returns formatted tag list' do
        expect(data).to receive(:say).with(text: ':cat: :dog: :bird:')
        plugin.get_tag_list(data, nil)
      end
    end

    context 'when no tags exist' do
      before do
        allow(http_client).to receive(:get).with("https://#{illust_server}/tag")
                                           .and_return(double(code: 200, body: ''))
      end

      it 'returns message indicating no tags' do
        expect(data).to receive(:say).with(text: 'タグが登録されていません')
        plugin.get_tag_list(data, nil)
      end
    end
  end

  describe '#register_fav' do
    let(:image_url) { 'https://example.com/image.jpg' }
    let(:data) do
      build_event(
        messages: [{ blocks: [{ image_url: image_url }] }]
      )
    end
    let(:reaction) { 'thumbsup' }

    context 'when image URL exists' do
      before do
        allow(http_client).to receive(:post).with(
          "https://#{illust_server}/tag",
          { file: image_url, tag: reaction }
        ).and_return(double(code: 200))
      end

      it 'successfully registers the favorite' do
        expect(plugin.instance_variable_get(:@logger)).to receive(:info)
          .with("Successfully registered favorite for reaction: #{reaction}")
        plugin.register_fav(data, reaction)
      end
    end

    context 'when image URL does not exist' do
      let(:data) { build_event(messages: [{ blocks: [{}] }]) }

      it 'returns early without processing' do
        expect(http_client).not_to receive(:post)
        plugin.register_fav(data, reaction)
      end
    end
  end

  describe '#get_tag' do
    let(:emojis) { %w[cat dog] }
    let(:data) { build_event(text: ':cat: :dog:') }
    let(:matcher) { data.text.match(/^(?:(?::.+:)(?:\s)?)+$/) }

    context 'when parent URL is not available' do
      let(:cat_lines) { "image1.jpg\nimage2.jpg" }
      let(:dog_lines) { "image2.jpg\nimage3.jpg" }
      let(:selected_image) { 'image2.jpg' }
      let(:image_tags) { %w[nature animal] }

      before do
        allow(data).to receive(:parent_url).and_return([nil, nil])
        allow(http_client).to receive(:get).with("https://#{illust_server}/cat.txt")
                                           .and_return(double(code: 200, body: cat_lines))
        allow(http_client).to receive(:get).with("https://#{illust_server}/dog.txt")
                                           .and_return(double(code: 200, body: dog_lines))
        allow(http_client).to receive(:get).with(
          "https://#{illust_server}/ilusttag",
          params: { url: selected_image }
        ).and_return(double(code: 200, body: image_tags.to_json))

        # Mock random selection
        allow_any_instance_of(Array).to receive(:sample).and_return(selected_image)
      end

      it 'displays image with tags' do
        expected_blocks = [
          {
            type: 'image',
            title: {
              type: 'plain_text',
              text: ':nature: :animal:'
            },
            image_url: selected_image,
            alt_text: 'nature animal'
          }
        ]

        expect(data).to receive(:say).with(blocks: expected_blocks)
        plugin.get_tag(data, matcher)
      end
    end

    context 'when parent URL is available (delete mode)' do
      let(:parent_url) { 'https://example.com/parent.jpg' }
      let(:parent_ts) { '123456789' }

      before do
        allow(data).to receive(:parent_url).and_return([parent_url, parent_ts])
        emojis.each do |emoji|
          allow(http_client).to receive(:post).with(
            "https://#{illust_server}/delete_tag/#{emoji}",
            { keyword: parent_url }
          ).and_return(double(code: 200))
        end
      end

      it 'deletes tags from the image' do
        emojis.each do |emoji|
          expect(data).to receive(:say).with(
            text: "タグ :#{emoji}: を削除しました",
            thread_ts: parent_ts
          )
        end
        plugin.get_tag(data, matcher)
      end
    end
  end
end
