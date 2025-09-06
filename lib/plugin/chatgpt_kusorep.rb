# frozen_string_literal: true

require_relative 'chatgpt/chatgpt'

class ChatGPTKusorep < ChatGPT
  def initialize(options:, logger:)
    super

    reaction_set('kusorep', 'ChatGPTにクソリプを作成させる') { |data:, reaction:| kusorep_create(data, reaction) }
  end

  def kusorep_create(data, reaction)
    @logger.info "Received message for Kusorep: #{reaction}"

    messages = data.messages

    word = messages.first[:text]
    system_message = 'あなたはTwitterにいるクソリプが得意な人です。質問に対して日本語で140文字以内でクソリプをしてください。'
    kusorep_response = send_message(word, system_message)
    @logger.info "ChatGPT Kusorep response: #{kusorep_response}"

    data.say(text: kusorep_response, thread_ts: data.ts)
  rescue StandardError => e
    @logger.error "Error in kusorep_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}", thread_ts: data.ts)
  end
end
