# frozen_string_literal: true

require 'json'

module Backup
  class << self
    def backup(data, filepath)
      File.open(filepath, 'w') do |f|
        JSON.dump(data, f)
      end
    end

    def load_backup(filepath)
      return unless File.exist?(filepath)

      data = []
      File.open(filepath) do |f|
        data = JSON.parse(f.read, symbolize_names: true)
      end
      data
    end

    def backup_job(text, filepath)
      File.write(filepath, text)
    end

    def load_backup_job(filepath)
      return 'あなたは高性能AIです。' unless File.exist?(filepath)

      File.read(filepath)
    end
  end
end
