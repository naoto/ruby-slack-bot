# frozen_string_literal: true

class IllustCommandHandler
  DEFAULT_SEED = -1

  def initialize(job_queue:, translator:, logger:)
    @job_queue = job_queue
    @translator = translator
    @logger = logger
  end

  def handle_japanese_illust(data, prompt)
    @logger.info "Received japanese illustration request: #{prompt}"

    seed, ts = extract_parent_info(data)
    translated_prompt = @translator.translate_to_english(prompt)

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: prompt,
      seed: seed,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "handle_japanese_illust")
  end

  def handle_english_illust(data, prompt)
    @logger.info "Received english illustration request: #{prompt}"

    seed, ts = extract_parent_info(data)

    enqueue_job(
      prompt: prompt,
      org_prompt: prompt,
      seed: seed,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "handle_english_illust")
  end

  def handle_img2img(data, prompt)
    @logger.info "Received img2img request: #{prompt}"

    url, ts = data.get_parent_url
    return handle_missing_parent_image(data) if url.nil?

    translated_prompt = @translator.translate_to_english(prompt)
    @logger.info "Translated prompt: #{translated_prompt}, url: #{url}"

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: prompt,
      seed: nil,
      url: url,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "handle_img2img")
  end

  def handle_hokusai(data, subject)
    prompt = "葛飾北斎が描いた浮世絵版「#{subject}\""
    @logger.info "Received hokusai request: #{prompt}"

    seed, ts = extract_parent_info(data)
    translated_prompt = @translator.translate_to_english(prompt)

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: prompt,
      seed: seed,
      ts: ts,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "handle_hokusai")
  end

  def handle_poem(data, word)
    @logger.info "Received poem request: #{word}"

    translated_prompt = @translator.generate_poem_prompt(word)
    japanese_prompt = @translator.translate_to_japanese(translated_prompt)

    enqueue_job(
      prompt: translated_prompt,
      org_prompt: japanese_prompt,
      seed: nil,
      ts: nil,
      data: data
    )
  rescue StandardError => e
    handle_error(e, data, "handle_poem")
  end

  def handle_queue_status(data)
    queue_length = @job_queue.size
    @logger.info "Current queue size: #{queue_length}"
    
    contents = @job_queue.contents
    data.say(text: "現在のイラスト生成キューの長さは #{queue_length} です。")
    data.say(text: contents.map{ |m| m[:org_prompt] }.join("\n")) if !contents.nil? && !contents.empty?
  rescue StandardError => e
    @logger.error "Error in handle_queue_status: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  private

  def enqueue_job(**job_params)
    success = @job_queue.enqueue(job_params)
    
    unless success
      job_params[:data].say(text: "現在処理中のため、しばらく待ってから再度お試しください。")
    end
    
    success
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
end
