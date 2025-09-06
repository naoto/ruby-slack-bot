# frozen_string_literal: true

class IllustWorker
  def initialize(job_queue:, generator:, logger:)
    @job_queue = job_queue
    @generator = generator
    @logger = logger
    @running = false
    @thread = nil
  end

  def start
    return if @running

    @running = true
    @thread = Thread.start { work_loop }
  end

  def stop
    @running = false
    @thread&.join
  end

  private

  def work_loop
    while @running && (job = @job_queue.dequeue)
      @logger.info "Processing job from queue: #{job}"
      process_job(job)
    end
  end

  def process_job(job)
    url = generate_image_for_job(job)
    return unless url

    send_response(job, url)
  rescue StandardError => e
    handle_generation_error(e, job, 'イラストの生成に失敗しました')
  end

  def generate_image_for_job(job)
    if job.key?(:url)
      @generator.generate_img2img(url: job[:url], prompt: job[:prompt])
    else
      @generator.generate_text2img(prompt: job[:prompt], seed: job[:seed])
    end
  end

  def send_response(job, image_url)
    job[:data].say(
      blocks: build_response_blocks(image_url, job[:prompt], job[:org_prompt]),
      thread_ts: job[:ts],
      reply_broadcast: true
    )
  end

  def handle_generation_error(error, job, message)
    error_message = "#{message}: #{error.message}"
    thread_ts = job[:ts] || job[:data].ts
    job[:data].say(text: error_message, thread_ts: thread_ts)
    @logger.error error_message
  end

  def build_response_blocks(url, prompt, org_prompt)
    [
      {
        type: 'image',
        title: {
          type: 'plain_text',
          text: org_prompt
        },
        block_id: 'image4',
        image_url: url,
        alt_text: prompt
      }
    ]
  end
end
