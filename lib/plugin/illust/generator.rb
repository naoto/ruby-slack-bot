# frozen_string_literal: true

class IllustGenerator
  MAX_RETRIES = 3
  RETRY_DELAY = 10

  def initialize(stable_diffusion:, logger:)
    @stable_diffusion = stable_diffusion
    @logger = logger
  end

  def generate_text2img(prompt:, seed: nil)
    with_retry("text2img generation") do
      @stable_diffusion.sd_start
      @stable_diffusion.generate(prompt: prompt, seed: seed)
    end
  ensure
    @stable_diffusion.sd_stop
  end

  def generate_img2img(url:, prompt:)
    with_retry("img2img generation") do
      @stable_diffusion.sd_start
      @stable_diffusion.generate_i2i(url: url, prompt: prompt)
    end
  ensure
    @stable_diffusion.sd_stop
  end

  private

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
end
