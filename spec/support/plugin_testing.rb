# frozen_string_literal: true

require 'json'

module PluginTesting
  module DSL
    def test_logger
      instance_double('Logger', info: nil, warn: nil, error: nil, debug: nil)
    end

    def build_event(text: '', say: nil, **extras)
      say ||= ->(**_) {}
      defaults = { text: text, say: say }
      instance_double('Event', **defaults.merge(extras))
    end

    def build_plugin(klass, options: {}, logger: test_logger)
      klass.new(options: options, logger: logger)
    end
  end

  module HTTPS
    def stub_http_get(url, body: {}, raw_body: nil)
      return unless defined?(RestClient)

      response = instance_double(RestClient::Response, body: raw_body || JSON.dump(body))
      allow(RestClient).to receive(:get).with(url).and_return(response)
    end
  end

  module HandlerMatchers
    extend RSpec::Matchers::DSL

    matcher :have_handler do |expected_pattern|
      match do |plugin|
        keyword_methods = plugin.respond_to?(:keyword_method_list) ? plugin.keyword_method_list : []
        keyword_methods.any? { |handler| handler[:regex] == expected_pattern }
      end

      failure_message do |plugin|
        "expected plugin #{plugin.class} to have handler for pattern #{expected_pattern}, but it does not"
      end
    end
  end
end
