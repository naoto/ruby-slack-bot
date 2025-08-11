# frozen_string_literal: true

require 'rspec'
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :except }
  config.filter_run_when_matching :focus
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.include PluginTesting::DSL
  config.include PluginTesting::HTTPS
  config.include PluginTesting::HandlerMatchers
end
