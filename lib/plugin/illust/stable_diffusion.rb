# frozen_string_literal: true
require 'json'
require 'securerandom'

class StableDiffusion
  def initialize(logger:)
    @logger = logger
    @cwd = ENV['SD_PATH']
    @cmd = "./webui.sh"
    @stable_diffusion_host = ENV['STABLE_DIFFUSION_HOST']
    @image_server_host = ENV['IMAGE_SERVER_HOST']
  end

  def args
    [
      "--skip-python-version-check",
      "--skip-torch-cuda-test",
      "--nowebui",
      "--no-hashing",
      "--skip-version-check",
      "--allow-code",
      "--medvram",
      "--xformers",
      "--enable-insecure-extension-access",
      "--api",
      "--opt-channelslast",
      "--disable-gpu-warning",
    ]
  end

  def sd_start
    @logger.info "Starting SD process"
    sd_stop()

    @process = Process.spawn(@cmd, *args, chdir: @cwd, pgroup: true)
    sleep 25
  end

  
  def sd_stop
    @logger.info "Stopping SD process: #{@process}"
    unless @process.nil?
      status = Process.waitpid2(@process, Process::WNOHANG)

      if status.nil?
        Process.kill("TERM", -@process)
        Process.wait(@process)
        @logger.info "SD process stopped: #{@process}"
      else
        @logger.info "SD process is not running: #{@process}"
      end
    end
    @logger.info "SD process stopped"
  rescue Errno::ESRCH, Errno::ECHILD => e
    @logger.warn "Error stopping SD process: #{e.message}"
  rescue StandardError => e
    @logger.error "Unexpected error stopping SD process: #{e.message}"
  end

  def txt2img_payload(
    enable_hr: false,
    denoising_strength: 0,
    firstphase_width: 0,
    firstphase_height: 0,
    hr_scale: 2,
    hr_upscaler: "string",
    hr_second_pass_steps: 0,
    hr_resize_x: 0,
    hr_resize_y: 0,
    prompt: "",
    styles: [""],
    seed: -1,
    subseed: -1,
    subseed_strength: 0,
    seed_resize_from_h: -1,
    seed_resize_from_w: -1,
    sampler_name: "Euler a",
    sanoker_index: "Euler a",
    scheduler: "Simple",
    batch_size: 1,
    n_iter: 1,
    steps: 25,
    cfg_scale: 1,
    distilled_cfg_scale: 3.5,
    width: 512,
    height: 512,
    restore_faces: false,
    tiling: false,
    do_not_save_samples: false,
    do_not_save_grid: false,
    negative_prompt: "",
    eta: 0,
    s_churn: 0,
    s_tmax: 0,
    s_tmin: 0,
    s_noise: 1,
    override_settings: {},
    override_settings_restore_afterwards: true,
    script_args: [],
    send_images: true,
    save_images: false,
    alwayson_scripts: {}
  )
    {
      enable_hr:,
      denoising_strength:,
      firstphase_width:,
      firstphase_height:,
      hr_scale:,
      hr_upscaler:,
      hr_second_pass_steps:,
      hr_resize_x:,
      hr_resize_y:,
      prompt:,
      styles:,
      seed:,
      subseed:,
      subseed_strength:,
      seed_resize_from_h:,
      seed_resize_from_w:,
      sampler_name:,
      sanoker_index:,
      scheduler:,
      batch_size:,
      n_iter:,
      steps:,
      cfg_scale:,
      distilled_cfg_scale:,
      width:,
      height:,
      restore_faces:,
      tiling:,
      do_not_save_samples:,
      do_not_save_grid:,
      negative_prompt:,
      eta:,
      s_churn:,
      s_tmax:,
      s_tmin:,
      s_noise:,
      override_settings:,
      override_settings_restore_afterwards:,
      script_args:,
      send_images:,
      save_images:,
      alwayson_scripts:
    }
  end

  def img2img_payload(
    prompt: "",
    negative_prompt: "",
    seed: -1,
    batch_size: 1,
    n_iter: 1,
    steps: 25,
    cfg_scale: 1,
    scheduler: "Simple",
    distilled_cfg_scale: 3.5,
    width: 512,
    height: 512,
    denoising_strength: 0.75,
    comments: {},
    init_images: nil,
    sampler_index: "Euler a"
  )
    {
      prompt:,
      negative_prompt:,
      seed:,
      batch_size:,
      n_iter:,
      steps:,
      cfg_scale:,
      scheduler:,
      distilled_cfg_scale:,
      width:,
      height:,
      denoising_strength:,
      comments:,
      init_images:,
      sampler_index:}
  end

  def generate(prompt:, seed: nil)
    payload_json = txt2img_payload(prompt:, seed:)
    @logger.info "Sending generation request with payload: #{payload_json}"

    response = RestClient::Request.execute(
      method: :post,
      url: url_text_to_image,
      payload: payload_json.to_json,
      headers: {content_type: :json, accept: :json},
      timeout: 600,
      open_timeout: 60
    )
    json_response = JSON.parse(response.body, symbolize_names: true)

    send_images(json_response)
  end

  def generate_i2i(prompt:, url:)
    response = RestClient.get(url)
    image_data = response.body
    b64image = Base64.strict_encode64(image_data)

    payload_json = img2img_payload(prompt:, init_images: [b64image])
    payload_json = payload_json.to_json

    @logger.info "Sending img2img generation request with payload: #{payload_json}"
    response = RestClient::Request.execute(
      method: :post,
      url: "#{@stable_diffusion_host}/sdapi/v1/img2img",
      payload: payload_json,
      headers: {content_type: :json, accept: :json},
      timeout: 600,
      open_timeout: 60
    )
    json_response = JSON.parse(response.body, symbolize_names: true)

    send_images(json_response)
  end

  private

  def send_images(response)
    seed = JSON.parse(response[:info], symbolize_names: true)[:seed]
    @logger.info "Generated image with seed: #{seed}"
    data = Base64.decode64(response[:images].first)

    filename = save_file(data)

    response = RestClient.post(
      image_server_url,
      { imagedata: File.new("./#{filename}", "rb") },
      { content_type: 'multipart/form-data' }
    )

    File.delete(filename) if File.exist?(filename)

    url = response.body.strip + "?seed=#{seed}"
    RestClient.get(url) # URLが有効か確認するためにアクセスしておく
    @logger.info "Image URL: #{url}"
    url
  end

  def save_file(data)
    name = "#{filename(10)}.png"
    File.open(name, "wb") do |f|
      f.write(data)
    end

    name
  end

  def filename(n)
    chars = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map(&:to_a).flatten
    Array.new(n) { chars[SecureRandom.random_number(chars.size)] }.join
  end

  def image_server_url
    "http://#{@image_server_host}/"
  end

  def url_text_to_image
    "http://#{@stable_diffusion_host}/sdapi/v1/txt2img"
  end

end