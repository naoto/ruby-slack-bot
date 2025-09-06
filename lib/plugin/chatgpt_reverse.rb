# frozen_string_literal: true

require_relative 'chatgpt/chatgpt'

class ChatGPTReverse < ChatGPT
  def initialize(options:, logger:)
    super

    set(/^対義語[[:space:]](.*)$/, 'ChatGPTに対義語を作成させる') { |data:, matcher:| antonym_create(data, matcher) }
  end

  def antonym_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for antonym creation: #{word}"

    system_message = '質問を単語毎に分解して対義語を返してください。一例として「とびだせどうぶつの森」は「ひっこめ人間の砂漠」になります'
    messages = [
      { role: 'system', content: system_message },
      { role: 'user', content: 'とびだせどうぶつの森' },
      { role: 'assistant', content: 'ひっこめ人間の砂漠' },
      { role: 'user', content: word }
    ]

    response = data.chatgpt(messages)
    @logger.info "ChatGPT antonym response: #{response}"

    data.say(text: response)
  rescue StandardError => e
    @logger.error "Error in antonym_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end
end
