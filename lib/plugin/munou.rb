# frozen_string_literal: true

require_relative 'ollama/ollama'

class Munou < Ollama
  MAX_HISTORY_SIZE = 20

  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @history = []

    register_handlers
  end

  def munou_search(data, matcher)
    word = extract_search_word(matcher)
    log_search_request(word)

    answer = perform_search(word)
    respond_with_result(data, answer)
  rescue StandardError => e
    handle_error(data, e, 'munou_search')
  end

  def munou_chat(data, matcher)
    user_message = extract_chat_message(matcher)
    log_chat_request(user_message)

    response = generate_chat_response(user_message)
    answer = extract_response_content(response)
    
    update_conversation_history(user_message, answer)
    respond_with_result(data, answer)
  rescue StandardError => e
    handle_error(data, e, 'munou_chat')
  end

  def clear_history
    @history.clear
    @logger.info "Conversation history cleared"
  end

  def history_size
    @history.size
  end

  # 履歴リセット用のコマンドハンドラーを追加
  def register_reset_handler
    set(/^無能[[:space:]]リセット$/, '無能の会話履歴をリセット') do |data:|
      clear_history
      data.say(text: "会話履歴をリセットしました。")
    end
  end

  attr_reader :logger

  private

  def register_handlers
    set(/^(無能|むのう)[[:space:]](.*)$/, '無能と会話する') do |data:, matcher:|
      munou_chat(data, matcher)
    end
    
    set(/^(.*)調べて$/, '無能に調べさせる') do |data:, matcher:|
      munou_search(data, matcher)
    end

    register_reset_handler
  end

  def extract_search_word(matcher)
    matcher[1]
  end

  def extract_chat_message(matcher)
    matcher[2]
  end

  def log_search_request(word)
    @logger.info "Received message for munou_search: #{word}"
  end

  def log_chat_request(message)
    @logger.info "Received message for munou_chat: #{message}"
  end

  def perform_search(word)
    answer = search(word)
    @logger.info "Ollama search response: #{answer}"
    answer
  end

  def generate_chat_response(user_message)
    current_history = @history.dup # Use current history without the new message
    response = send_message(context: user_message, history: current_history)
    @logger.info "Ollama response: #{response}"
    response
  end

  def extract_response_content(response)
    response[:message][:content]
  end

  def update_conversation_history(user_message, assistant_response)
    add_to_history({ role: 'user', content: user_message })
    add_to_history({ role: 'assistant', content: assistant_response })
    limit_history_size
  end

  def add_to_history(message)
    @history << message
  end

  def limit_history_size
    return unless @history.size > MAX_HISTORY_SIZE

    @history.shift(2) # Remove oldest user-assistant pair
    @logger.info "History trimmed to #{@history.size} messages"
  end

  def respond_with_result(data, answer)
    data.say(text: answer)
  end

  def handle_error(data, error, method_name)
    error_message = "Error in #{method_name}: #{error.message}"
    @logger.error error_message
    data.say(text: "エラーが発生しました: #{error.message}")
  end
end
