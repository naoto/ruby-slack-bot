# frozen_string_literal: true

require 'rest-client'
require 'json'

# Dog Plugin
# 犬の画像を表示する
class IllustFav < Plugin::Base
  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @illust_server = ENV['ILLUST_SERVER']
    set(/^(?:(?::.+:)(?:\s)?)+$/, '絵文字のタグが付いた画像を表示する') { |data:, matcher:| get_tag(data, matcher) }
    set(/^tag$/, 'タグ一覧を表示する') { |data:, matcher:| get_tag_list(data, matcher) }
    set(/^count\s+(?:(?::.+:)(?:\s)?)+$/, '絵文字のタグが付いた画像の数を表示する') { |data:, matcher:| get_tag_count(data, matcher) }

    reaction_set(/^.*$/, '画像にタグを登録する') { |data:, reaction:| register_fav(data, reaction) }
  end

  def get_tag_count(data, matcher)
    emojis = matcher[0].scan(/:(.+?):/).flatten
    @logger.info "Received emojis for count: #{emojis.join(', ')}"

    line_sets = []
    emojis.each do |emoji|
      @logger.info "Fetching image for emoji: #{emoji}"
      resp = RestClient.get("https://#{@illust_server}/#{emoji}.txt")
      if resp.code == 200
        lines = resp.body.split("\n").map(&:strip).reject(&:empty?)
        line_sets << lines
      else
        @logger.warn "Failed to fetch image for emoji: #{emoji}, status code: #{resp.code}"
        return
      end
    end

    if line_sets.empty?
      @logger.warn 'No images found for the provided emojis.'
      return
    end

    count = line_sets.reduce(&:&).size
    @logger.info "Count of common images: #{count}"

    data.say(text: "#{matcher[0]}: #{count}")
  rescue StandardError => e
    @logger.error "Error in get_tag_count: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}", thread_ts: data.thread_ts || data.ts)
  end

  def get_tag_list(data, _)
    resp = RestClient.get("https://#{@illust_server}/tag")
    if resp.code == 200 && !resp.body.empty?
      tags = JSON.parse(resp.body)
      @logger.info "Fetched tags: #{tags.join(', ')}"
    else
      tags = []
    end

    if tags.empty?
      data.say(text: 'タグが登録されていません')
    else
      data.say(text: tags.map { |t| ":#{t}:" }.join(' '))
    end
  rescue StandardError => e
    @logger.error "Error in get_tag_list: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}", thread_ts: data.thread_ts || data.ts)
  end

  def register_fav(data, reaction)
    @logger.info "Received reaction for registering favorite: #{reaction}"

    url = data.messages.first[:blocks].first[:image_url]

    if url.nil?
      return
    end

    payload = { file: url, tag:  reaction}
    res = RestClient.post("https://#{@illust_server}/tag", payload)

    if res.code == 200
      @logger.info "Successfully registered favorite for reaction: #{reaction}"
    else
      @logger.warn "Failed to register favorite for reaction: #{reaction}, status code: #{res.code}"
    end
  rescue StandardError => e
    @logger.error "Error in register_fav: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}", thread_ts: data.thread_ts || data.ts)
  end
  
  def get_tag(data, matcher)
    emojis = matcher[0].scan(/:(.+?):/).flatten
    @logger.info "Received emojis: #{emojis.join(', ')}"

    url, ts = get_parent_url(data)

    if url.nil?
      # urlが取得できなかった時は指定されたタグの画像を取得する
      line_sets = []
      emojis.each do |emoji|
        @logger.info "Fetching image for emoji: #{emoji}"
        resp = RestClient.get("https://#{@illust_server}/#{emoji}.txt")
        if resp.code == 200
          lines = resp.body.split("\n").map(&:strip).reject(&:empty?)
          line_sets << lines
        else
          @logger.warn "Failed to fetch image for emoji: #{emoji}, status code: #{resp.code}"
          return
        end
      end

      if line_sets.empty?
        @logger.warn 'No images found for the provided emojis.'
        return
      end

      image_url = line_sets.reduce(&:&).sample
      @logger.info "Selected image URL: #{image_url}"
      if image_url.nil? || image_url.empty?
        @logger.warn 'No common image URL found for the provided emojis.'
        return
      end

      payload = { url: image_url }
      res = RestClient.get("https://#{@illust_server}/ilusttag", params: payload)
      if res.code == 200 && !res.body.empty?
        tags = JSON.parse(res.body)
        @logger.info "Fetched tags: #{tags.join(', ')}"
      else
        tags = []
      end

      blocks = [
        {
          "type": 'image',
          "title": {
            "type": 'plain_text',
            "text": tags.map { |t| ":#{t}:" }.join(' ')
          },
          "image_url": image_url,
          "alt_text": tags.join(' ')
        }
      ]

      data.say(blocks: blocks)
    else
      # urlが取得できた時はタグを削除する
      emojis.each do |emoji|
        @logger.info "Registering favorite for emoji: #{emoji} with URL: #{url}"
        payload = { keyword: url }
        res = RestClient.post("https://#{@illust_server}/delete_tag/#{emoji}", payload)

        if res.code == 200
          @logger.info "Successfully deleted for emoji: #{emoji}"
          data.say(text: "タグ :#{emoji}: を削除しました", thread_ts: ts)
        else
          @logger.warn "Failed to delete for emoji: #{emoji}, status code: #{res.code}"
          data.say(text: ":#{emoji}: の削除に失敗しました...", thread_ts: ts)
        end
      end
    end
  end

  def get_parent_url(data)
    if data.thread_ts
      thread = data.conversations_history(
        channel: data.channel, oldest: data.thread_ts, latest: data.thread_ts, inclusive: 1
      )

      messages = thread[:messages]
      @logger.info "Thread messages: #{messages}"
      
      if messages.nil? || messages.empty?
        @logger.warn 'No messages found in thread.'
        group_history = data.conversations_replies(
          channel: data.channel, ts: data.thread_ts
        )
        messages = group_history[:messages]
        @logger.info "Group history messages: #{messages}"
      end

      if messages && !messages.empty?
        return messages.first[:blocks].first[:image_url], data.thread_ts
      else
        @logger.warn 'No messages found in group history.'
        return nil, nil
      end
    end

    return nil, nil
  rescue StandardError => e
    @logger.error "Error fetching parent URL: #{e.message}"
    return nil, nil
  end
end