# frozen_string_literal: true

module RubySlackBot
  # 引数引き渡しの為のDataクラス
  # Slackのイベントデータをラップして、プラグインに渡す
  # プラグインはこのクラスを通じて、メッセージのテキストや応答を処理する
  class Data
    def initialize(data = {}, client = nil)
      @data = data
      @client = client
      @logger = Logger.new($stdout, level: Logger::Severity::INFO)
    end

    def text
      @data[:text]
    end

    def channel
      @data[:event][:channel] || @data[:event][:item][:channel]
    end

    def ts
      @data[:event][:item][:ts]
    end

    def thread_ts
      @data[:event][:thread_ts]
    end

    def say(**response)
      response[:channel] = channel

      @logger.info "Sending message: #{response}"
      @client.call('chat.postMessage', response)
    end

    def conversations_history(**params)
      @logger.info "Fetching conversation history for params: #{params}"

      @client.call('conversations.history', params)
    end

    def conversations_replies(**params)
      @logger.info "Fetching conversations replies for params: #{params}"

      @client.get_call('conversations.replies', params)
    end

    def messages
      history = conversations_history(
        channel: channel, oldest: ts, latest: ts, inclusive: true
      )
      messages = history[:messages]
      @logger.info "Conversation history: #{history} with messages: #{messages}"

      if messages.nil? || messages.empty?
        @logger.warn 'No messages found in conversation history.'
        group_history = conversations_replies(
          channel: channel, ts: ts
        )
        messages = group_history[:messages]
        @logger.info "Group conversation history: #{group_history} with messages: #{messages}"
      end

      messages
    end

    def get_parent_url
      return nil, nil if thread_ts.nil?
      thread = conversations_history(
        channel: channel, oldest: thread_ts, latest: thread_ts, inclusive: 1
      )

      messages = thread[:messages]
      @logger.info "Thread messages: #{messages}"
      
      if messages.nil? || messages.empty?
        @logger.warn 'No messages found in thread.'
        group_history = conversations_replies(
          channel: channel, ts: thread_ts
        )
        messages = group_history[:messages]
        @logger.info "Group history messages: #{messages}"
      end

      if messages && !messages.empty? && !messages.first[:blocks].first.nil?
        return messages.first[:blocks].first[:image_url], thread_ts
      end

      text = messages.first[:text]
      url_match = text.match(/https?:\/\/[^\s?]+(?:\?[^\s]*)?/)
      if url_match
        return url_match[0], thread_ts
      end

      @logger.warn 'No messages found in group history.'
      return nil, nil
    rescue StandardError => e
      @logger.error "Error fetching parent URL: #{e.message}"
      return nil, nil
    end
  end
end
