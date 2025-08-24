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
  end
end
