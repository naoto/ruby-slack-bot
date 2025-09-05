# frozen_string_literal: true

class IllustTranslator
  def initialize(chat_client:)
    @chat_client = chat_client
  end

  def translate_to_english(japanese_text)
    @chat_client.send_message(
      japanese_text,
      'あなたは優秀な通訳です。以下の日本語を自然な英語に翻訳してください。返答は翻訳した内容だけにしてください。'
    )
  end

  def translate_to_japanese(english_text)
    @chat_client.send_message(
      english_text,
      'あなたは優秀な通訳です。以下の英語を自然な日本語に翻訳してください。返答は翻訳した内容だけにしてください。'
    )
  end

  def generate_poem_prompt(word)
    @chat_client.send_message(
      word,
      'あなたは画像生成ＡＩのプロンプト職人です。ワードの場面を情景的に英語で説明してください。'
    )
  end
end
