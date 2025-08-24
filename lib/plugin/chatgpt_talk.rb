# frozen_string_literal: true

require_relative 'chatgpt/chatgpt'
require_relative 'chatgpt/backup'

class ChatGPTTalk < ChatGPT
  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @talk_history_file = 'talk_history.json'
    @talk_job_system_file = 'talk_job_system.json'
    @message_history = Backup.load_backup(@talk_history_file) || []
    @talk_system = Backup.load_backup_job(@talk_job_system_file)

    set(/^なおぼっと\s(.*)$/, 'ChatGPTと会話する') { |data:, matcher:| message_talk(data, matcher) }
    set(/^job$/, 'ChatGPTのシステムプロンプトを表示する') { |data:, matcher:| job_display(data, matcher) }
    set(/^job\s(.*)$/, 'ChatGPTのシステムプロンプトを設定する') { |data:, matcher:| job_set(data, matcher) }
    set(/^job reset$/, 'ChatGPTのシステムプロンプトをリセットする') { |data:, matcher:| job_reset(data, matcher) }
    set(/^talk reset$/, 'ChatGPTの会話履歴をリセットする') { |data:, matcher:| talk_reset(data, matcher) }
  end

  def message_talk(data, matcher)
    word = matcher[1]
    @logger.info "Received message for ChatGPT: #{word}"

    @message_history << { role: 'user', content: word }

    message = @message_history.dup
    message.unshift({ role: 'system', content: @talk_system })

    answer = chatgpt(message)
    @logger.info "ChatGPT response: #{answer}"

    @message_history << { role: 'assistant', content: answer }
    data.say(text: answer)
    Backup.backup(@message_history, @talk_history_file)
  rescue StandardError => e
    @logger.error "Error in message_talk: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def job_display(data, _matcher)
    @logger.info "Displaying ChatGPT job: #{@talk_system}"
    data.say(text: "job #{@talk_system}")
  end

  def job_set(data, matcher)
    new_job = matcher[1]
    @logger.info "Setting new ChatGPT job: #{new_job}"

    if new_job.empty?
      data.say(text: 'システムプロンプトを設定するには、`job <内容>`と入力してください。')
      return
    end

    @talk_system = new_job
    Backup.backup_job(@talk_system, @talk_job_system_file)
    data.say(text: "新しいシステムプロンプトを設定しました: #{@talk_system}")
  rescue StandardError => e
    @logger.error "Error in job_set: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def job_reset(data, _matcher)
    @logger.info 'Resetting ChatGPT job to default.'
    @talk_system = 'あなたは高性能AIです。'
    Backup.backup_job(@talk_system, @talk_job_system_file)
    data.say(text: 'システムプロンプトをリセットしました。')
  rescue StandardError => e
    @logger.error "Error in job_reset: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def talk_reset(data, _matcher)
    @logger.info 'Resetting ChatGPT talk history.'
    @message_history = []
    Backup.backup(@message_history, @talk_history_file)
    data.say(text: '会話履歴をリセットしました。')
  rescue StandardError => e
    @logger.error "Error in talk_reset: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end
end
