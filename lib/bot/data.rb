# frozen_string_literal: true

module RubySlackBot
  # 引数引き渡しの為のDataクラス
  # Slackのイベントデータをラップして、プラグインに渡す
  # プラグインはこのクラスを通じて、メッセージのテキストや応答を処理する
  class Data
    attr_reader :data

    def initialize(data = {}, client = nil)
      @data = data
      @client = client
      @logger = Logger.new($stdout, level: Logger::Severity::INFO)
      @logger.info @data[:event]
    end

    def text
      @data[:text]
    end

    def channel
      @data[:event][:channel] || @data[:event][:item][:channel]
    end

    def ts
      @data[:event][:item][:ts] || @data[:event][:ts]
    end

    def thread_ts
      @data[:event][:thread_ts]
    end

    def user
      @data[:event][:user]
    end

    def say(**response)
      response[:channel] = channel

      @logger.info "Sending message: #{response}"
      @client.call('chat.postMessage', response)
    end

    def conversations_history(**params)
      @logger.info "Fetching conversation history for params: #{params}"

      @client.call('conversations.history', params)
    rescue StandardError => e
      @logger.error "Error fetching conversation history: #{e.message}"
      @logger.error e.backtrace.join("\n")
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

    def parent_url
      return [nil, nil] if thread_ts.nil?

      messages = fetch_thread_messages
      return [nil, nil] if messages.nil? || messages.empty?

      extract_url_from_messages(messages)
    rescue StandardError => e
      @logger.error "Error fetching parent URL: #{e.message}"
      [nil, nil]
    end

    private

    def fetch_thread_messages
      thread = conversations_history(
        channel: channel, oldest: thread_ts, latest: thread_ts, inclusive: 1
      )

      messages = thread[:messages]
      @logger.info "Thread messages: #{messages}"

      return messages unless messages.nil? || messages.empty?

      @logger.warn 'No messages found in thread.'
      group_history = conversations_replies(
        channel: channel, ts: thread_ts
      )
      messages = group_history[:messages]
      @logger.info "Group history messages: #{messages}"

      messages
    end

    def extract_url_from_messages(messages)
      return [nil, nil] if messages.empty?

      first_message = messages.first

      # Check for image URL in blocks
      return [first_message[:blocks].first[:image_url], thread_ts] if image_block?(first_message)

      # Extract URL from text
      url = extract_url_from_text(first_message[:text])
      return [url, thread_ts] if url

      @logger.warn 'No URL found in messages.'
      [nil, nil]
    end

    def image_block?(message)
      message&.dig(:blocks, 0, :image_url)
    end

    def extract_url_from_text(text)
      return nil unless text

      url_match = text.match(%r{https?://[^\s<>?]+(?:\?[^\s<>]*)?})
      url_match&.[](0)
    end
  end
end
