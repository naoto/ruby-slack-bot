# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'uri'

# IllustFav Plugin
# 画像にタグを付けて管理する
class IllustFav < Plugin::Base
  def initialize(options:, logger:)
    super
    @illust_server = options[:illust_server] || ENV.fetch('ILLUST_SERVER', nil)
    @http_client = options[:http_client] || RestClient

    validate_configuration!
    register_handlers
  end

  def get_tag_count(data, matcher)
    emojis = extract_emojis_from_text(matcher[0])
    @logger.info "Received emojis for count: #{emojis.join(', ')}"

    line_sets = fetch_image_lists_for_emojis(emojis)
    return if line_sets.empty?

    count = calculate_common_images_count(line_sets)
    @logger.info "Count of common images: #{count}"

    data.say(text: "#{matcher[0]}: #{count}")
  rescue StandardError => e
    handle_error(e, data, 'get_tag_count')
  end

  def get_tag_list(data, _)
    tags = fetch_all_tags

    if tags.empty?
      data.say(text: 'タグが登録されていません')
    else
      formatted_tags = format_tags_for_display(tags)
      data.say(text: formatted_tags)
    end
  rescue StandardError => e
    handle_error(e, data, 'get_tag_list')
  end

  def register_fav(data, reaction)
    @logger.info "Received reaction for registering favorite: #{reaction}"

    image_url = extract_image_url_from_data(data)
    return if image_url.nil?

    register_tag_for_image(image_url, reaction)
  rescue StandardError => e
    @logger.error "Error in register_fav: #{e}"
    handle_error(e, data, 'register_fav')
  end

  def get_tag(data, matcher)
    emojis = extract_emojis_from_text(matcher[0])
    @logger.info "Received emojis: #{emojis.join(', ')}"

    url, timestamp = data.parent_url

    if url.nil?
      display_tagged_image(data, emojis)
    else
      delete_tags_from_image(data, emojis, url, timestamp)
    end
  rescue StandardError => e
    handle_error(e, data, 'get_tag')
  end

  private

  def validate_configuration!
    raise ArgumentError, 'ILLUST_SERVER is not configured' if @illust_server.nil? || @illust_server.empty?
  end

  def register_handlers
    set(/^(?:(?::.+:)(?:\s)?)+$/, '絵文字のタグが付いた画像を表示する') { |data:, matcher:| get_tag(data, matcher) }
    set(/^tag$/, 'タグ一覧を表示する') { |data:, matcher:| get_tag_list(data, matcher) }
    set(/^count[[:space:]]+(?:(?::.+:)(?:[[:space:]])?)+$/, '絵文字のタグが付いた画像の数を表示する') do |data:, matcher:|
      get_tag_count(data, matcher)
    end

    reaction_set(/^.*$/, '画像にタグを登録する') { |data:, reaction:| register_fav(data, reaction) }
  end

  # Helper methods

  def extract_emojis_from_text(text)
    text.scan(/:(.+?):/).flatten
  end

  def fetch_image_lists_for_emojis(emojis)
    line_sets = []

    emojis.each do |emoji|
      @logger.info "Fetching image for emoji: #{emoji}"
      begin
        resp = @http_client.get(build_emoji_url(emoji))

        if resp.code == 200
          lines = parse_image_list(resp.body)
          line_sets << lines
        else
          @logger.warn "Failed to fetch image for emoji: #{emoji}, status code: #{resp.code}"
          return []
        end
      rescue => e
        @logger.warn "Fetch image lists for emojis: #{e}"
        return []
      end
    end

    line_sets
  end

  def parse_image_list(body)
    body.split("\n").map(&:strip).reject(&:empty?)
  end

  def calculate_common_images_count(line_sets)
    return 0 if line_sets.empty?

    line_sets.reduce(&:&).size
  end

  def fetch_all_tags
    resp = @http_client.get(build_tag_list_url)

    if resp.code == 200 && !resp.body.empty?
      JSON.parse(resp.body)
    else
      []
    end
  end

  def format_tags_for_display(tags)
    tags.map { |t| ":#{t}:" }.join(' ')
  end

  def extract_image_url_from_data(data)
    @logger.info "extract_image_url_from_data: #{data.messages}"
    data.messages&.first&.dig(:blocks, 0, :image_url)
  end

  def register_tag_for_image(image_url, tag)
    payload = { file: image_url, tag: tag }
    @logger.info "register_tag_for_image: #{payload}"
    res = @http_client.post(build_tag_registration_url, payload)

    if res.code == 200
      @logger.info "Successfully registered favorite for reaction: #{tag}"
    else
      @logger.warn "Failed to register favorite for reaction: #{tag}, status code: #{res.code}"
    end
  end

  def display_tagged_image(data, emojis)
    line_sets = fetch_image_lists_for_emojis(emojis)
    return if line_sets.empty?

    image_url = select_random_common_image(line_sets)
    return if image_url.nil? || image_url.empty?

    tags = fetch_tags_for_image(image_url)
    blocks = build_image_blocks(image_url, tags)

    data.say(blocks: blocks)
  end

  def select_random_common_image(line_sets)
    common_images = line_sets.reduce(&:&)
    @logger.warn 'No common image URL found for the provided emojis.' if common_images.empty?

    selected = common_images.sample
    @logger.info "Selected image URL: #{selected}" if selected
    selected
  end

  def fetch_tags_for_image(image_url)
    payload = { url: image_url }
    res = @http_client.get(build_image_tags_url, params: payload)

    if res.code == 200 && !res.body.empty?
      tags = JSON.parse(res.body)
      @logger.info "Fetched tags: #{tags.join(', ')}"
      tags
    else
      []
    end
  end

  def build_image_blocks(image_url, tags)
    [
      {
        type: 'image',
        title: {
          type: 'plain_text',
          text: format_tags_for_display(tags)
        },
        image_url: image_url,
        alt_text: tags.join(' ')
      }
    ]
  end

  def delete_tags_from_image(data, emojis, url, timestamp)
    emojis.each do |emoji|
      @logger.info "Deleting tag for emoji: #{emoji} with URL: #{url}"

      if delete_tag_from_server?(emoji, url)
        data.say(text: "タグ :#{emoji}: を削除しました", thread_ts: timestamp)
      else
        data.say(text: ":#{emoji}: の削除に失敗しました...", thread_ts: timestamp)
      end
    end
  end

  def delete_tag_from_server?(emoji, url)
    payload = { keyword: url }
    res = @http_client.post(build_tag_deletion_url(emoji), payload)

    if res.code == 200
      @logger.info "Successfully deleted tag for emoji: #{emoji}"
      true
    else
      @logger.warn "Failed to delete tag for emoji: #{emoji}, status code: #{res.code}"
      false
    end
  end

  def handle_error(error, data, method_name)
    @logger.error "Error in #{method_name}: #{error.message}"
    data.say(text: "エラーが発生しました: #{error.message}", thread_ts: data.thread_ts || data.ts)
  end

  # URL building methods

  def build_emoji_url(emoji)
    "https://#{@illust_server}/#{URI.encode_www_form_component(emoji)}.txt"
  end

  def build_tag_list_url
    "https://#{@illust_server}/tag"
  end

  def build_tag_registration_url
    "https://#{@illust_server}/tag"
  end

  def build_image_tags_url
    "https://#{@illust_server}/ilusttag"
  end

  def build_tag_deletion_url(emoji)
    "https://#{@illust_server}/delete_tag/#{URI.encode_www_form_component(emoji)}"
  end
end
