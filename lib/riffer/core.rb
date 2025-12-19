# frozen_string_literal: true

require "logger"

module Riffer
  class Core
    attr_reader :logger, :storage_registry

    def initialize
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @storage_registry = {}
    end

    def configure
      yield self if block_given?
    end

    def register_storage(name, adapter)
      @storage_registry[name] = adapter
    end

    def get_storage(name)
      @storage_registry[name]
    end
  end
end
