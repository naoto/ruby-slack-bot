# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/plugin/illust/generator'

RSpec.describe IllustGenerator do
  let(:stable_diffusion) { double('StableDiffusion') }
  let(:logger) { test_logger }
  let(:generator) { IllustGenerator.new(stable_diffusion: stable_diffusion, logger: logger) }

  before do
    allow(stable_diffusion).to receive(:sd_start)
    allow(stable_diffusion).to receive(:sd_stop)
  end

  describe '#generate_text2img' do
    let(:prompt) { 'a beautiful landscape' }
    let(:seed) { 42 }

    context 'when generation succeeds' do
      before do
        allow(stable_diffusion).to receive(:generate).and_return('http://example.com/image.png')
      end

      it 'generates an image and returns the URL' do
        result = generator.generate_text2img(prompt: prompt, seed: seed)

        expect(result).to eq('http://example.com/image.png')
        expect(stable_diffusion).to have_received(:sd_start)
        expect(stable_diffusion).to have_received(:generate).with(prompt: prompt, seed: seed)
        expect(stable_diffusion).to have_received(:sd_stop)
      end
    end

    context 'when generation fails' do
      before do
        allow(stable_diffusion).to receive(:generate).and_raise(StandardError, 'Generation failed')
      end

      it 'retries up to MAX_RETRIES times' do
        expect do
          generator.generate_text2img(prompt: prompt, seed: seed)
        end.to raise_error(StandardError, 'Generation failed')

        expect(stable_diffusion).to have_received(:generate).exactly(IllustGenerator::MAX_RETRIES + 1).times
        expect(stable_diffusion).to have_received(:sd_stop).at_least(IllustGenerator::MAX_RETRIES + 1).times
        expect(logger).to have_received(:error).at_least(IllustGenerator::MAX_RETRIES).times
      end
    end
  end

  describe '#generate_img2img' do
    let(:url) { 'http://example.com/source.png' }
    let(:prompt) { 'modify this image' }

    context 'when generation succeeds' do
      before do
        allow(stable_diffusion).to receive(:generate_i2i).and_return('http://example.com/result.png')
      end

      it 'generates an image and returns the URL' do
        result = generator.generate_img2img(url: url, prompt: prompt)

        expect(result).to eq('http://example.com/result.png')
        expect(stable_diffusion).to have_received(:sd_start)
        expect(stable_diffusion).to have_received(:generate_i2i).with(url: url, prompt: prompt)
        expect(stable_diffusion).to have_received(:sd_stop)
      end
    end

    context 'when generation fails' do
      before do
        allow(stable_diffusion).to receive(:generate_i2i).and_raise(StandardError, 'I2I failed')
      end

      it 'retries up to MAX_RETRIES times' do
        expect { generator.generate_img2img(url: url, prompt: prompt) }.to raise_error(StandardError, 'I2I failed')

        expect(stable_diffusion).to have_received(:generate_i2i).exactly(IllustGenerator::MAX_RETRIES + 1).times
        expect(stable_diffusion).to have_received(:sd_stop).at_least(IllustGenerator::MAX_RETRIES + 1).times
        expect(logger).to have_received(:error).at_least(IllustGenerator::MAX_RETRIES).times
      end
    end
  end
end
