# frozen_string_literal: true
# rbs_inline: enabled

require "logger"

# Riffer::Core provides core functionality for the Riffer framework.
#
# Handles logging and configuration for the framework.
class Riffer::Core
  # The logger instance for Riffer.
  attr_reader :logger #: Logger

  #: () -> void
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @storage_registry = {}
  end

  # Yields self for configuration.
  #
  #: () ?{ (Riffer::Core) -> void } -> void
  def configure(&block)
    yield self if block_given?
  end
end
