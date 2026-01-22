# frozen_string_literal: true

require "logger"

# Riffer::Core provides core functionality for the Riffer framework.
#
# Handles logging and configuration for the framework.
class Riffer::Core
  # The logger instance for Riffer.
  #
  # Returns Logger.
  attr_reader :logger

  # Initializes the core object and logger.
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @storage_registry = {}
  end

  # Yields self for configuration.
  #
  # Yields core (Riffer::Core) to the block.
  def configure
    yield self if block_given?
  end
end
