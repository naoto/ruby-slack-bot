# frozen_string_literal: true

require 'dotenv/load'
require 'bot/client'
require 'plugin/base'

# RubySlackBot main module
module RubySlackBot
  # Main entry point for the Ruby Slack Bot
  class << self
    def start(_args)
      client = RubySlackBot::Client.new(ENV['SLACK_BOT_TOKEN'], ENV['SLACK_APP_TOKEN'])
      client.run
    end
  end
end
