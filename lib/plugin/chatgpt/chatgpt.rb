# frozen_string_literal: true

require 'openai'
require 'tiktoken_ruby'
require_relative '../base'

class ChatGPT < Plugin::Base
  MODEL = 'gpt-4o-mini'

  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @chatgpt_api_key = ENV['CHATGPT_API_KEY']
  end

  def send_message(context, system_message)
    @logger.info("Sending message to ChatGPT with context: #{context}")

    messages = [
      { role: 'system', content: system_message },
      { role: 'user', content: context }
    ]

    answer = chatgpt(messages)
    @logger.info("Received response from ChatGPT: #{answer}")

    answer
  end

  def chatgpt(messages, size = 3800)
    messages = token_slice(messages, size)
    @logger.info("ChatGPT messages after slicing: #{messages}")

    client = OpenAI::Client.new(api_key: @chatgpt_api_key)
    completions = client.chat.completions.create(messages:, model: MODEL)
    completions.choices.first.message.content
  rescue StandardError => e
    @logger.error("Error communicating with ChatGPT: #{e.message}")
    e.message
  end

  def token_slice(messages, size = 3800)
    @logger.info("Token slicing messages: #{messages}")
    enc = Tiktoken.encoding_for_model(MODEL)

    token_total = 0
    if messages.first[:role] == 'system'
      system_tokens = enc.encode(messages.first[:content])
      token_total = system_tokens.size
    end
    @logger.info("Initial token count: #{token_total}")
    active = []
    messages.reverse.each do |m|
      tokens = enc.encode(m[:content])
      if m[:role] == 'system' || (tokens.size + token_total) <= size
        active << m
        token_total += tokens.size
      end
    end

    @logger.info("Token count after slicing: #{token_total}")
    active.reverse
  end
end
