# frozen_string_literal: true

require_relative 'chatgpt/chatgpt'

class ChatGPTAA < ChatGPT
  def initialize(options:, logger:)
    super(options: options, logger: logger)

    set(/^aa\s(.*)$/, 'ChatGPTにAAを作成させる') { |data:, matcher:| aa_create(data, matcher) }
  end

  def aa_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for AA creation: #{word}"

    # ここでChatGPTにAAを生成させる処理を実装
    system_message = 'あなたは匿名掲示板にるAA職人です。質問されたものをAAで作成してください。作成したAAはmarkdownのcodeブロックで囲んで回答してください'
    aa_response = send_message(word, system_message)
    @logger.info "ChatGPT AA response: #{aa_response}"

    data.say(text: aa_response)
  rescue StandardError => e
    @logger.error "Error in aa_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end
end
