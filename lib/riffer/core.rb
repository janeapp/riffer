# frozen_string_literal: true
# rbs_inline: enabled

require "logger"

# Riffer::Core provides core functionality for the Riffer framework.
#
# Handles logging and configuration for the framework.
class Riffer::Core
  #: @logger: Logger
  #: @storage_registry: Hash[String, untyped]

  # The logger instance for Riffer.
  attr_reader :logger #: Logger

  #: return: void
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @storage_registry = {}
  end

  # Yields self for configuration.
  #
  #: &block: (Riffer::Core) -> void
  #: return: void
  def configure(&block)
    yield self if block_given?
  end
end
