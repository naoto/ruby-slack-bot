# frozen_string_literal: true

module RubySlackBot
  # 引数引き渡しの為のDataクラス
  # Slackのイベントデータをラップして、プラグインに渡す
  # プラグインはこのクラスを通じて、メッセージのテキストや応答を処理する
  class Data
    def initialize(data = {}, &block)
      @data = data
      @block = block
    end

    def text
      @data[:text]
    end

    def say(text:)
      @block.call(text)
    end
  end
end
