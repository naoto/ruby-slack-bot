# frozen_string_literal: true

require 'dotenv/load'
require 'bot/client'
require 'plugin/base'

# RubySlackBot main module
module RubySlackBot
  # Main entry point for the Ruby Slack Bot
  class << self
    def start(_args)
      client = RubySlackBot::Client.new(ENV.fetch('SLACK_BOT_TOKEN', nil), ENV.fetch('SLACK_APP_TOKEN', nil))
      client.run
    end
  end
end
