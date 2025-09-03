# frozen_string_literal: true

require 'thread'
require_relative 'chatgpt/chatgpt'

class Illust < ChatGPT
  MAX_RETRIES = 3
  RETRY_DELAY = 10
  DEFAULT_SEED = -1
  QUEUE_SIZE = 10

  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @queue = SizedQueue.new(QUEUE_SIZE)
    @thread = start_worker_thread
    @stable_diffusion = StableDiffusion.new(logger: logger)

    register_commands
  end

  def register_commands
    set(/^イラスト[[:space:]](.*)$/, '日本語のプロンプトでイラストを作成させる') { |data:, matcher:| illust_jp_create(data, matcher) }
    set(/^illust[[:space:]](.*)$/, '英語のプロンプトでイラストを作成させる') { |data:, matcher:| illust_en_create(data, matcher) }
    set(/^i2i[[:space:]](.*)$/, 'img2imgでイラストを作成させる') { |data:, matcher:| illust_i2i_create(data, matcher) }
    set(/^葛飾北斎[[:space:]](.*)$/, '葛飾北斎風のイラストを作成させる') { |data:, matcher:| hokusai_create(data, matcher) }
    set(/^ポエム[[:space:]](.*)$/, 'ポエムを元にイラストを作成させる') { |data:, matcher:| poem_create(data, matcher) }
    set(/^イラストキュー$/, 'イラスト生成キューの状態を表示する') { |data:, matcher:| queue_status(data, matcher) }
  end

  def queue_status(data, _matcher)
    queue_length = @queue.size
    @logger.info "Current queue size: #{queue_length}"
    
    q = @queue.instance_variable_get(:@que).dup
    data.say(text: "現在のイラスト生成キューの長さは #{queue_length} です。")
    data.say(text: q.join("\n")) if !q.nil? && !q.empty?
  rescue StandardError => e
    @logger.error "Error in queue_status: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def poem_create(data, matcher)
    word = matcher[1]
    @logger.info "Received poem request: #{word}"

    translated_prompt = generate_poem_prompt(word)
    japanese_prompt = translate_jp(translated_prompt)

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: japanese_prompt,
      seed: nil,
      ts: nil,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "poem_create")
  end

  def hokusai_create(data, matcher)
    word = "葛飾北斎が描いた浮世絵版「#{matcher[1]}」"
    @logger.info "Received hokusai request: #{word}"

    seed, ts = extract_parent_info(data)
    translated_prompt = translate(word)

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: word,
      seed: seed,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "hokusai_create")
  end

  def illust_i2i_create(data, matcher)
    word = matcher[1]
    @logger.info "Received img2img request: #{word}"

    url, ts = data.get_parent_url
    return handle_missing_parent_image(data) if url.nil?

    translated_prompt = translate(word)
    @logger.info "Translated prompt: #{translated_prompt}, url: #{url}"

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: word,
      seed: nil,
      url: url,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "illust_i2i_create")
  end

  def illust_en_create(data, matcher)
    word = matcher[1]
    @logger.info "Received english illustration request: #{word}"

    seed, ts = extract_parent_info(data)

    enqueue_job(
      prompt: word,
      org_prompt: word,
      seed: seed,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "illust_en_create")
  end

  def illust_jp_create(data, matcher)
    word = matcher[1]
    @logger.info "Received japanese illustration request: #{word}"

    seed, ts = extract_parent_info(data)
    translated_prompt = translate(word)

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: word,
      seed: seed,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "illust_jp_create")
  end

  private

  def enqueue_job(**job_params)
    @logger.info "Enqueueing job: prompt=#{job_params[:prompt]}, seed=#{job_params[:seed]}"
    
    begin
      @queue.push(job_params, true)
    rescue ThreadError
      # キューが満杯の場合の処理
      @logger.warn "Queue is full, rejecting job"
      job_params[:data].say(text: "現在処理中のため、しばらく待ってから再度お試しください。")
      return false
    end

    true
  end

  def handle_error(error, data, method_name)
    @logger.error "Error in #{method_name}: #{error.message}"
    data.say(text: "エラーが発生しました: #{error.message}")
  end

  def handle_missing_parent_image(data)
    data.say(
      text: "元画像のURLが取得できません。スレッド内で実行してください。",
      thread_ts: data.thread_ts || data.ts
    )
  end

  def extract_parent_info(data)
    url, ts = data.get_parent_url
    return DEFAULT_SEED, nil if url.nil?

    seed = extract_seed_from_url(url)
    [seed, ts]
  rescue StandardError => e
    @logger.error "Error extracting parent info: #{e.message}"
    [DEFAULT_SEED, nil]
  end

  def extract_seed_from_url(url)
    match = url.match(/[?&]seed=([^&]+)/)
    match ? match[1] : DEFAULT_SEED
  end

  def generate_poem_prompt(word)
    send_message(
      word,
      'あなたは画像生成ＡＩのプロンプト職人です。ワードの場面を情景的に英語で説明してください。'
    )
  end

  def start_worker_thread
    Thread.start do
      process_queue_continuously
    end
  end

  def process_queue_continuously
    while job = @queue.pop
      @logger.info "Processing job from queue: #{job}"
      process_single_job(job)
    end
  end

  def process_single_job(job)
    url = generate_image_for_job(job)
    return unless url

    send_response(job, url)
  ensure
    @stable_diffusion.sd_stop
  end

  def generate_image_for_job(job)
    if job.key?(:url)
      generate_img2img_worker(job)
    else
      generate_text2img_worker(job)
    end
  rescue => e
    @logger.error "Error generating image: #{e.message}"
    nil
  end

  def send_response(job, image_url)
    job[:data].say(
      blocks: build_response_blocks(image_url, job[:prompt], job[:org_prompt]),
      thread_ts: job[:ts],
      reply_broadcast: true
    )
  end

  def generate_text2img_worker(job)
    with_retry("text2img generation") do
      @stable_diffusion.sd_start
      @stable_diffusion.generate(
        prompt: job[:prompt],
        seed: job[:seed]
      )
    end
  rescue => e
    handle_generation_error(e, job, "イラストの生成に失敗しました")
    raise
  end

  def generate_img2img_worker(job)
    with_retry("img2img generation") do
      @stable_diffusion.sd_start
      @stable_diffusion.generate_i2i(
        url: job[:url],
        prompt: job[:prompt]
      )
    end
  rescue => e
    handle_generation_error(e, job, "イラストの生成に失敗しました")
    raise
  end

  def with_retry(operation_name)
    retry_count = 0
    begin
      yield
    rescue => e
      @logger.error "Error in #{operation_name}: #{e.message}"
      @stable_diffusion.sd_stop

      if retry_count < MAX_RETRIES
        retry_count += 1
        @logger.info "Retrying #{operation_name} (#{retry_count}/#{MAX_RETRIES})"
        sleep RETRY_DELAY
        retry
      else
        raise
      end
    end
  end

  def handle_generation_error(error, job, message)
    error_message = "#{message}: #{error.message}"
    thread_ts = job[:ts] || job[:data].ts
    job[:data].say(text: error_message, thread_ts: thread_ts)
  end

  def build_response_blocks(url, prompt, org_prompt)
    [
      {
        type: "image",
        title: {
          type: "plain_text",
          text: org_prompt
        },
        block_id: "image4",
        image_url: url,
        alt_text: prompt
      }
    ]
  end

  def translate(text)
    send_message(
      text,
      'あなたは優秀な通訳です。以下の日本語を自然な英語に翻訳してください。返答は翻訳した内容だけにしてください。'
    )
  end

  def translate_jp(text)
    send_message(
      text,
      'あなたは優秀な通訳です。以下の英語を自然な日本語に翻訳してください。返答は翻訳した内容だけにしてください。'
    )
  end

  # Deprecated: このメソッドは extract_parent_info に置き換えられました
  def get_parent_seed_and_thread_ts(data)
    extract_parent_info(data)
  end
end