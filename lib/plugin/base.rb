# frozen_string_literal: true

module Plugin
  # Plugin 作成のsためのベースクラス
  # このクラスを継承して、プラグインを実装する
  class Base
    attr_reader :keyword_method_list

    def initialize(options: {}, logger: Logger.new($stdout))
      @options = options
      @logger = logger
      @keyword_method_list = []
    end

    def set(regex, help, &block)
      @keyword_method_list << { regex: regex, help: help, block: block }
    end
  end
end
