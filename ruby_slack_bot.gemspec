# frozen_string_literal: true

require 'English'

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'ruby_slack_bot'
  spec.version       = '0.0.1'
  spec.authors       = ['Naoto SHINGAKI']
  spec.email         = ['n.shingaki@gmail.com']
  spec.summary       = 'Ruby Slack Bot'
  spec.description   = 'A simple Ruby bot for Slack using the Slack Ruby Client.'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.4.1'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'

  spec.add_dependency 'dotenv'
  spec.add_dependency 'slack_socket_mode_bot'

  spec.add_dependency 'base64'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'openai'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'tiktoken_ruby'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
