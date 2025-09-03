# frozen_string_literal: true

require_relative 'ollama/ollama'

class Munou < Ollama
  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @history = []

    set(/^(無能|むのう)[[:space:]](.*)$/, '無能と会話する') { |data:, matcher:| munou_chat(data, matcher) }
    set(/^(.*)調べて$/, '無能に調べさせる') { |data:, matcher:| munou_search(data, matcher) }
  end

  def munou_search(data, matcher)
    word = matcher[1]
    @logger.info "Received message for munou_search: #{word}"

    answer = search(word)
    @logger.info "Ollama search response: #{answer}"
    
    data.say(text: answer)
  rescue StandardError => e
    @logger.error "Error in munou_search: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def munou_chat(data, matcher)
    word = matcher[2]
    @logger.info "Received message for munou_chat: #{word}"

    response = send_message(context: word, history: @history)
    @logger.info "Ollama response: #{response}"

    answer = response[:message][:content]
    @history << { role: 'assistant', content: word }
    
    data.say(text: answer)
  rescue StandardError => e
    @logger.error "Error in munou_chat: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end
end
