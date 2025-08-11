# frozen_string_literal: true

require 'rest-client'

# Dog Plugin
# 犬の画像を返す
class Dog < Plugin::Base
  def initialize(options:, logger:)
    super(options: options, logger: logger)
    set(/^dog$/i, '犬の画像を返す') { |data:, matcher:| message(data, matcher) }
  end

  def message(data, _)
    text = data.text
    @logger.info "Received message: #{text}"

    resp = RestClient.get('https://dog.ceo/api/breeds/image/random')
    json = JSON.parse(resp.body)

    data.say(text: json['message'])
  end
end
