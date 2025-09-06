# frozen_string_literal: true

require 'rest-client'

# Dog Plugin
# 犬の画像を表示する
class Dog < Plugin::Base
  def initialize(options:, logger:)
    super
    set(/^dog$/i, '犬の画像を表示する') { |data:, matcher:| message(data, matcher) }
  end

  def message(data, _)
    text = data.text
    @logger.info "Received message: #{text}"

    resp = RestClient.get('https://dog.ceo/api/breeds/image/random')
    json = JSON.parse(resp.body)

    blocks = [
      {
        type: 'image',
        title: {
          type: 'plain_text',
          text: 'dog!'
        },
        alt_text: 'dog!',
        block_id: 'image4',
        image_url: json['message']
      }
    ]
    data.say(blocks:)
  end
end
