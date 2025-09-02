# frozen_string_literal: true

require 'thread'
require_relative 'chatgpt/chatgpt'

class Illust < ChatGPT
  def initialize(options:, logger:)
    super(options: options, logger: logger)
    @queue = SizedQueue.new(1)
    @thread = worker_run
    @stable_diffusion = StableDiffusion.new(logger: logger)

    set(/^イラスト\s(.*)$/, '日本語のプロンプトでイラストを作成させる') { |data:, matcher:| illust_jp_create(data, matcher) }
    set(/^illust\s(.*)$/, '英語のプロンプトでイラストを作成させる') { |data:, matcher:| illust_en_create(data, matcher) }
    set(/^i2i\s(.*)$/, 'img2imgでイラストを作成させる') { |data:, matcher:| illust_i2i_create(data, matcher) }
    set(/^葛飾北斎\s(.*)$/, '葛飾北斎風のイラストを作成させる') { |data:, matcher:| hokusai_create(data, matcher) }
    set(/^ポエム\s(.*)$/, 'ポエムを元にイラストを作成させる') { |data:, matcher:| poem_create(data, matcher) }
  end

  def poem_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for illustration creation: #{word}"

    translated_word = send_message(word, 'あなたは画像生成ＡＩのプロンプト職人です。ワードの場面を情景的に英語で説明してください。')
    @logger.info "Translated prompt: #{translated_word}"

    translated_word_jp = translate_jp(translated_word)

    # ここでQueueにジョブを追加する
    @queue.push({prompt: translated_word, org_prompt: translated_word_jp, seed: nil, ts: nil, data:})

  rescue StandardError => e
    @logger.error "Error in poem_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def hokusai_create(data, matcher)
    word = "葛飾北斎が描いた浮世絵版「#{matcher[1]}」"
    @logger.info "Received message for illustration creation: #{word}"

    seed, ts = get_parent_seed_and_thread_ts(data)
    translated_word = translate(word)
    @logger.info "Translated prompt: #{translated_word}, Seed: #{seed}"

    # ここでQueueにジョブを追加する
    @queue.push({prompt: translated_word, org_prompt: word, seed:, ts:, data:})

  rescue StandardError => e
    @logger.error "Error in illust_jp_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def illust_i2i_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for illustration creation: #{word}"

    url, ts = data.get_parent_url
    if url.nil?
      data.say(text: "元画像のURLが取得できません。スレッド内で実行してください。", thread_ts: data.thread_ts || data.ts)
      return
    end

    translated_word = translate(word)
    @logger.info "Translated prompt: #{translated_word}, url: #{url}"

    # ここでQueueにジョブを追加する
    @queue.push({prompt: translated_word, org_prompt: word, seed: nil, url:, ts:, data:})

  rescue StandardError => e
    @logger.error "Error in illust_i2i_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def illust_en_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for illustration creation: #{word}"

    seed, ts = get_parent_seed_and_thread_ts(data)
    @logger.info "Translated Seed: #{seed}"

    # ここでQueueにジョブを追加する
    @queue.push({prompt: word, org_prompt: word, seed:, ts:, data:})
    
  rescue StandardError => e
    @logger.error "Error in illust_en_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  def illust_jp_create(data, matcher)
    word = matcher[1]
    @logger.info "Received message for illustration creation: #{word}"

    seed, ts = get_parent_seed_and_thread_ts(data)
    translated_word = translate(word)
    @logger.info "Translated prompt: #{translated_word}, Seed: #{seed}"

    # ここでQueueにジョブを追加する
    @queue.push({prompt: translated_word, org_prompt: word, seed:, ts:, data:})

  rescue StandardError => e
    @logger.error "Error in illust_jp_create: #{e.message}"
    data.say(text: "エラーが発生しました: #{e.message}")
  end

  private

  def worker_run
    Thread.start do
      while resource = @queue.pop
        @logger.info "Processing resource from queue: #{resource}"
        retry_cnt = 0

        begin
          if !resource.key?(:url)
            url = generate_text2img_worker(resource)
          else
            url = generate_img2img_worker(resource)
          end
        rescue => e
          @logger.error "Error generating image worker: #{e.message}"
          next
        end

        retry_cnt = 0
        resource[:data].say(
          blocks: response(url, resource[:prompt], resource[:org_prompt]),
          thread_ts: resource[:ts],
          reply_broadcast: true
        )
        @stable_diffusion.sd_stop();
      end
    end
  end

  def generate_text2img_worker(resource)
    retry_cnt = 0

    begin
      @stable_diffusion.sd_start();
      @stable_diffusion.generate(
        prompt: resource[:prompt],
        seed: resource[:seed],
      )
    rescue => e
      @logger.error "Error generating image generate_text2img_worker: #{e.message}"
      @stable_diffusion.sd_stop();

      if retry_cnt < 3
        retry_cnt += 1
        sleep 10
        retry
      else
        resource[:data].say(text: "イラストの生成に失敗しました: #{e.message}", thread_ts: resource[:ts] || resource[:data].ts)
        raise Error
      end
    end
  end

  def generate_img2img_worker(resource)
    retry_cnt = 0

    begin
      @stable_diffusion.sd_start();
      @stable_diffusion.generate_i2i(
        url: resource[:url],
        prompt: resource[:prompt],
      )
    rescue => e
      @logger.error "Error generating image generate_img2img_worker: #{e.message}"
      if retry_cnt < 3
        retry_cnt += 1
        sleep 10
        retry
      else
        resource[:data].say(text: "イラストの生成に失敗しました: #{e.message}", thread_ts: resource[:ts] || resource[:data].ts)
        raise Error
      end
    end
  end

  def response(url, prompt, org_prompt)
    [
      {
        type: "image",
        title: {
          type: "plain_text",
          text: prompt
        },
        block_id: "image4",
        image_url: url,
        alt_text: org_prompt
      }
    ]
  end

  def translate(text)
    send_message(text, 'あなたは優秀な通訳です。以下の日本語を自然な英語に翻訳してください。返答は翻訳した内容だけにしてください。')
  end

  def translate_jp(text)
    send_message(text, 'あなたは優秀な通訳です。以下の英語を自然な日本語に翻訳してください。返答は翻訳した内容だけにしてください。')
  end

  def get_parent_seed_and_thread_ts(data)
    url, ts = data.get_parent_url
    return -1, nil if url.nil?

    url.match(/[?&]seed=([^&]+)/)
    seed = match ? match[1] : -1

    return seed, ts
  rescue StandardError => e
    @logger.error "Error fetching parent seed and thread ts: #{e.message}"
    [-1, nil]
  end
end
