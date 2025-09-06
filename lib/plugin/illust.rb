# frozen_string_literal: true

require_relative 'chatgpt/chatgpt'
require_relative 'illust/job_queue'
require_relative 'illust/generator'
require_relative 'illust/translator'
require_relative 'illust/worker'
require_relative 'illust/command_handler'

class Illust < ChatGPT
  QUEUE_SIZE = 10

  def initialize(options:, logger:)
    super

    @stable_diffusion = StableDiffusion.new(logger: logger)
    @job_queue = IllustJobQueue.new(max_size: QUEUE_SIZE, logger: logger)
    @generator = IllustGenerator.new(stable_diffusion: @stable_diffusion, logger: logger)
    @translator = IllustTranslator.new(chat_client: self)
    @worker = IllustWorker.new(job_queue: @job_queue, generator: @generator, logger: logger)
    @command_handler = IllustCommandHandler.new(
      job_queue: @job_queue,
      translator: @translator,
      logger: logger
    )

    @worker.start
    register_commands
  end

  def register_commands
    set(/^イラスト[[:space:]](.*)$/, '日本語のプロンプトでイラストを作成させる') do |data:, matcher:|
      @command_handler.handle_japanese_illust(data, matcher[1])
    end

    set(/^illust[[:space:]](.*)$/, '英語のプロンプトでイラストを作成させる') do |data:, matcher:|
      @command_handler.handle_english_illust(data, matcher[1])
    end

    set(/^i2i[[:space:]](.*)$/, 'img2imgでイラストを作成させる') do |data:, matcher:|
      @command_handler.handle_img2img(data, matcher[1])
    end

    set(/^葛飾北斎[[:space:]](.*)$/, '葛飾北斎風のイラストを作成させる') do |data:, matcher:|
      @command_handler.handle_hokusai(data, matcher[1])
    end

    set(/^ポエム[[:space:]](.*)$/, 'ポエムを元にイラストを作成させる') do |data:, matcher:|
      @command_handler.handle_poem(data, matcher[1])
    end

    set(/^イラストキュー$/, 'イラスト生成キューの状態を表示する') do |data:, **|
      @command_handler.handle_queue_status(data)
    end
  end

  def cleanup
    @worker.stop
  end
end
