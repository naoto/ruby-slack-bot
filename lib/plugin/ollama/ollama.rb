# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require_relative '../base'

class Ollama < Plugin::Base
  MODEL = 'gpt-oss:20b'

  def initialize(options:, logger:)
    super
    @chatgpt_api_key = ENV.fetch('CHATGPT_API_KEY', nil)
    @server = ENV.fetch('OLLAMA_SERVER', nil)
    @port = ENV['OLLAMA_PORT'] || '3000'
    @open_web_ui_server = ENV['OPEN_WEB_UI_SERVER'] || @server
    @open_web_ui_port = ENV.fetch('OPEN_WEB_UI_PORT', nil)
    @open_web_ui_token = ENV.fetch('OPEN_WEB_UI_TOKEN', nil)
  end

  def send_message_generate(prompt, format = nil)
    res = Net::HTTP.post(
      url('generate'),
      data(prompt:, format:),
      headers
    )
    JSON.parse(res.body, symbolize_names: true)
  end

  def send_message(context: nil, system_message: nil, history: nil, format: nil)
    @logger.info("Sending message to ChatGPT with context: #{context}")

    messages = history || []
    messages.unshift({ role: 'system', content: system_message }) unless system_message.nil?
    messages << { role: 'user', content: context }

    res = Net::HTTP.post(
      url('chat'),
      data(messages: messages, format: format),
      headers
    )
    JSON.parse(res.body, symbolize_names: true)
  end

  def search(context)
    @logger.info("Sending search request to OpenWebUI with context: #{context}")

    headers = {
      'Authorization' => "Bearer #{@open_web_ui_token}",
      'Content-Type' => 'application/json'
    }
    request_data = {
      'model' => 'gpt-oss:20b',
      'messages' => [
        { 'role' => 'system', 'content' => 'yamlで返答してください。必ず日本語で返答してください。' },
        { 'role' => 'user', 'content' => context }
      ],
      'features' => { 'web_search' => true }
    }
    @logger.info("OpenWebUI headers: #{headers}")
    @logger.info("OpenWebUI request data: #{request_data}")

    uri = open_web_ui_url('chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    # タイムアウト設定
    http.open_timeout = 600 # 接続確立のタイムアウト（秒）
    http.read_timeout = 600 # レスポンス読み取りのタイムアウト（秒）

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = request_data.to_json

    res = http.request(request)

    json = JSON.parse(res.body, symbolize_names: true)
    @logger.info("OpenWebUI response: #{json}")

    json[:choices][0][:message][:content]
  end

  private

  def open_web_ui_url(path = '')
    URI("http://#{@open_web_ui_server}:#{@open_web_ui_port}/api/#{path}")
  end

  def url(path = '')
    URI("http://#{@server}:#{@port}/ollama/api/#{path}")
  end

  def data(prompt: nil, messages: nil, format: nil)
    params = {
      model: MODEL,
      stream: false
    }

    raise StandardError('prompt and messages cannot be used together') if !prompt.nil? && !messages.nil?

    params[:prompt] = prompt unless prompt.nil?
    params[:messages] = messages unless messages.nil?
    params[:format] = format unless format.nil?

    @logger.info("Ollama request params: #{params}")

    JSON.dump(params)
  end

  def headers
    token = ENV.fetch('OLLAMA_API_KEY', nil)
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end
end
