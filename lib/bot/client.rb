# frozen_string_literal: true

require 'English'
require 'logger'
require 'slack_socket_mode_bot'
require 'bot/data'

module RubySlackBot
  # SlackBot の Client クラス
  class Client
    def initialize(bot_token, app_token)
      @logger = Logger.new($stdout, level: Logger::Severity::INFO)
      @bot_token = bot_token
      @app_token = app_token
      @instances = []
    end

    def run
      load_plugin
      setup_bot
      authenticate_bot
      @bot.run
    end

    private

    def load_plugin
      plugin_dir = File.expand_path('../plugin', __dir__)

      Dir.glob(File.join(plugin_dir, '**', '*.rb')).each do |file|
        before = subclasses_of(Plugin::Base)
        require file
        after = subclasses_of(Plugin::Base) - before

        after.each do |klass|
          @logger.info "Loaded plugin: #{klass}"
          @instances << klass.new(options: {}, logger: @logger)
        end
      end
    end

    def subclasses_of(klass)
      ObjectSpace.each_object(Class).select { |c| c < klass }
    end

    def setup_bot
      @bot = SlackSocketModeBot.new(token: @bot_token, app_token: @app_token, logger: @logger) do |data|
        handle_events_api(data) if data[:type] == 'events_api'
        @logger.info "Received data: #{data[:type]}: #{data[:payload]}" unless data[:type] == 'events_api'
      rescue StandardError => e
        @logger.error "Error processing data: #{e.message}"
        puts $ERROR_INFO.full_message
      end
    end

    def authenticate_bot
      auth = @bot.call('auth.test', {})
      @bot_user_id = auth['user_id']
      @bot_id = auth['bot_id']
      @logger.info "bot user_id: #{@bot_user_id} bot_id: #{@bot_id}"
    end

    def handle_events_api(data)
      event = data[:payload][:event]
      return if event[:user] == @bot_user_id

      @logger.info "Received data: #{data[:type]}"

      if event[:text] == 'help'
        handle_help_request(event)
      else
        process_plugin_keywords(data, event)
      end
    end

    def handle_help_request(event)
      @logger.info 'Received help request'
      help_text = @instances.map do |ins|
        ins.keyword_method_list.map do |keymap|
          "`#{keymap[:regex].inspect}`: #{keymap[:help]}"
        end
      end.flatten

      @bot.call('chat.postMessage', { channel: event[:channel], text: help_text.join("\n") })
    end

    def process_plugin_keywords(data, event)
      bot_data = RubySlackBot::Data.new(data[:payload]) do |text|
        @logger.info "Sending message: #{text}"
        @bot.call('chat.postMessage', { channel: event[:channel], text: text })
      end

      @instances.each do |ins|
        ins.keyword_method_list.each do |keymap|
          matcher = keymap[:regex].match(event[:text])
          keymap[:block].call(data: bot_data, matcher:) if matcher
        end
      end
    end
  end
end
