# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/bot/data'
require_relative '../../lib/plugin/illust/stable_diffusion'
require_relative '../../lib/plugin/illust'

RSpec.describe Illust do
  let(:options) { {} }
  let(:logger) { test_logger }
  let(:data) { build_event(text: 'test') }
  let(:stable_diffusion) { instance_double('StableDiffusion') }
  
  before do
    allow(StableDiffusion).to receive(:new).and_return(stable_diffusion)
    allow(stable_diffusion).to receive(:sd_start)
    allow(stable_diffusion).to receive(:sd_stop)
    allow(stable_diffusion).to receive(:generate).and_return('http://example.com/image.png')
    allow(stable_diffusion).to receive(:generate_i2i).and_return('http://example.com/image.png')
  end

  describe '#initialize' do
    it 'sets up the queue and worker components' do
      plugin = build_plugin(Illust, options: options, logger: logger)
      
      expect(plugin.instance_variable_get(:@job_queue)).to be_a(IllustJobQueue)
      expect(plugin.instance_variable_get(:@generator)).to be_a(IllustGenerator)
      expect(plugin.instance_variable_get(:@translator)).to be_a(IllustTranslator)
      expect(plugin.instance_variable_get(:@worker)).to be_a(IllustWorker)
      expect(plugin.instance_variable_get(:@command_handler)).to be_a(IllustCommandHandler)
    end

    it 'registers all commands' do
      plugin = build_plugin(Illust, options: options, logger: logger)
      
      expect(plugin).to have_handler(/^イラスト[[:space:]](.*)$/)
      expect(plugin).to have_handler(/^illust[[:space:]](.*)$/)
      expect(plugin).to have_handler(/^i2i[[:space:]](.*)$/)
      expect(plugin).to have_handler(/^葛飾北斎[[:space:]](.*)$/)
      expect(plugin).to have_handler(/^ポエム[[:space:]](.*)$/)
      expect(plugin).to have_handler(/^イラストキュー$/)
    end
  end

  describe 'command integration' do
    let(:plugin) { build_plugin(Illust, options: options, logger: logger) }
    let(:command_handler) { plugin.instance_variable_get(:@command_handler) }

    before do
      allow(command_handler).to receive(:handle_japanese_illust)
      allow(command_handler).to receive(:handle_english_illust)
      allow(command_handler).to receive(:handle_img2img)
      allow(command_handler).to receive(:handle_hokusai)
      allow(command_handler).to receive(:handle_poem)
      allow(command_handler).to receive(:handle_queue_status)
    end

    context 'イラスト command' do
      let(:matcher) { ['イラスト 猫', '猫'] }

      it 'delegates to command handler' do
        # Find the handler and execute it
        handlers = plugin.keyword_method_list
        illust_handler = handlers.find { |h| h[:regex] == /^イラスト[[:space:]](.*)$/ }
        
        illust_handler[:block].call(data: data, matcher: matcher)
        
        expect(command_handler).to have_received(:handle_japanese_illust).with(data, '猫')
      end
    end

    context 'illust command' do
      let(:matcher) { ['illust cat', 'cat'] }

      it 'delegates to command handler' do
        handlers = plugin.keyword_method_list
        illust_handler = handlers.find { |h| h[:regex] == /^illust[[:space:]](.*)$/ }
        
        illust_handler[:block].call(data: data, matcher: matcher)
        
        expect(command_handler).to have_received(:handle_english_illust).with(data, 'cat')
      end
    end

    context 'イラストキュー command' do
      let(:matcher) { ['イラストキュー'] }

      it 'delegates to command handler' do
        handlers = plugin.keyword_method_list
        queue_handler = handlers.find { |h| h[:regex] == /^イラストキュー$/ }
        
        queue_handler[:block].call(data: data, matcher: matcher)
        
        expect(command_handler).to have_received(:handle_queue_status).with(data)
      end
    end
  end

  describe '#cleanup' do
    let(:plugin) { build_plugin(Illust, options: options, logger: logger) }
    let(:worker) { plugin.instance_variable_get(:@worker) }

    it 'stops the worker' do
      allow(worker).to receive(:stop)
      
      plugin.cleanup
      
      expect(worker).to have_received(:stop)
    end
  end
end
