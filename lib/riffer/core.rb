# frozen_string_literal: true

require "logger"

# Riffer::Core provides core functionality for the Riffer framework.
#
# Handles logging and configuration for the framework.
class Riffer::Core
  # The logger instance for Riffer
  # @return [Logger]
  attr_reader :logger

  # Initializes the core object and logger
  # @return [void]
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @storage_registry = {}
  end

  # Yields self for configuration
  # @yieldparam core [Riffer::Core] the core object
  # @return [void]
  def configure
    yield self if block_given?
  end
end
