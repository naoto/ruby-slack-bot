# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/plugin/illust/translator'

RSpec.describe IllustTranslator do
  let(:chat_client) { double('ChatClient') }
  let(:translator) { IllustTranslator.new(chat_client: chat_client) }

  describe '#translate_to_english' do
    let(:japanese_text) { 'こんにちは' }
    let(:expected_result) { 'Hello' }

    before do
      allow(chat_client).to receive(:send_message).and_return(expected_result)
    end

    it 'translates Japanese text to English' do
      result = translator.translate_to_english(japanese_text)

      expect(result).to eq(expected_result)
      expect(chat_client).to have_received(:send_message).with(
        japanese_text,
        'あなたは優秀な通訳です。以下の日本語を自然な英語に翻訳してください。返答は翻訳した内容だけにしてください。'
      )
    end
  end

  describe '#translate_to_japanese' do
    let(:english_text) { 'Hello' }
    let(:expected_result) { 'こんにちは' }

    before do
      allow(chat_client).to receive(:send_message).and_return(expected_result)
    end

    it 'translates English text to Japanese' do
      result = translator.translate_to_japanese(english_text)

      expect(result).to eq(expected_result)
      expect(chat_client).to have_received(:send_message).with(
        english_text,
        'あなたは優秀な通訳です。以下の英語を自然な日本語に翻訳してください。返答は翻訳した内容だけにしてください。'
      )
    end
  end

  describe '#generate_poem_prompt' do
    let(:word) { '桜' }
    let(:expected_result) { 'Cherry blossoms falling gently in spring' }

    before do
      allow(chat_client).to receive(:send_message).and_return(expected_result)
    end

    it 'generates an artistic prompt for the word' do
      result = translator.generate_poem_prompt(word)

      expect(result).to eq(expected_result)
      expect(chat_client).to have_received(:send_message).with(
        word,
        'あなたは画像生成ＡＩのプロンプト職人です。ワードの場面を情景的に英語で説明してください。'
      )
    end
  end
end
