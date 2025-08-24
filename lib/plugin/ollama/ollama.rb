# frozen_string_literal: true

require "uri"
require "net/http"
require 'json'
require_relative '../base'

class Ollama < Plugin::Base
  MODEL = 'gpt-oss:20b'

  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @chatgpt_api_key = ENV['CHATGPT_API_KEY']
    @server = ENV['OLLAMA_SERVER']
    @port = ENV['OLLAMA_PORT'] || '3000'
  end

  def send_message_generate(prompt, format=nil)
    res = Net::HTTP.post(
      url("generate"),
      data(prompt:, format:),
      headers
    )
    json = JSON.parse(res.body, symbolize_names: true)

    json
  end

  def send_message(context: nil, system_message: nil, history: nil, format: nil)
    @logger.info("Sending message to ChatGPT with context: #{context}")

    messages = history || []
    messages.unshift({ role: 'system', content: system_message }) unless system_message.nil?
    messages << { role: 'user', content: context }

    res = Net::HTTP.post(
      url("chat"),
      data(messages: messages, format: format),
      headers
    )
    json = JSON.parse(res.body, symbolize_names: true)

    json
  end

  private

  def url(path = '')
    URI("http://#{@server}:#{@port}/ollama/api/#{path}")
  end

  def data(prompt: nil, messages: nil, format: nil)
    params = {
      model: MODEL,
      stream: false,
    }

    raise StandardError("prompt and messages cannot be used together") if !prompt.nil? && !messages.nil?

    params[:prompt] = prompt unless prompt.nil?
    params[:messages] = messages unless messages.nil?
    params[:format] = format unless format.nil?

    @logger.info("Ollama request params: #{params}")

    JSON::dump(params)
  end

  def headers
    token = ENV['OLLAMA_API_KEY']
    header = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }

    header
  end
end
