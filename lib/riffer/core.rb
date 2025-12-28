# frozen_string_literal: true

require "logger"

# Riffer::Core provides core functionality for the Riffer framework.
class Riffer::Core
  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @storage_registry = {}
  end

  def configure
    yield self if block_given?
  end
end
