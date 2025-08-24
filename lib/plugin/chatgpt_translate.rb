# frozen_string_literal: true

require_relative 'ollama/ollama'

class ChatGPTTranslate < ChatGPT
  def initialize(options:, logger:)
    super(options: options, logger: logger)

    reaction_set('jp', '日本語に翻訳する') { |data:, reaction:| translate_jp(data, reaction) }
    reaction_set('us', '英語に翻訳する') { |data:, reaction:| translate_en(data, reaction) }
  end

  def translate_jp(data, reaction)
    @logger.info "Received message for translation: #{reaction}"

    messages = data.messages
    word = messages.first[:text]
    @logger.info "Translating text: #{word}"

    system_message = 'あなたは通訳です。日本語に翻訳してください。返答は翻訳した内容だけにしてください。'
    translate_response = send_message(word, system_message)
    @logger.info "Translation response: #{translate_response}"

    data.say(text: translate_response, thread_ts: data.ts)
  rescue StandardError => e
    @logger.error "Error in translate_jp: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}", thread_ts: data.ts)
  end

  def translate_en(data, reaction)
    @logger.info "Received message for translation: #{reaction}"

    messages = data.messages
    word = messages.first[:text]
    @logger.info "Translating text: #{word}"

    system_message = 'あなたは通訳です。英語に翻訳してください。返答は翻訳した内容だけにしてください。'
    translate_response = send_message(word, system_message)
    @logger.info "Translation response: #{translate_response}"

    data.say(text: translate_response, thread_ts: data.ts)
  rescue StandardError => e
    @logger.error "Error in translate_en: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}", thread_ts: data.ts)
  end
end