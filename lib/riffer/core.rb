# frozen_string_literal: true
# rbs_inline: enabled

require "logger"

class Riffer::Core
  attr_reader :logger #: Logger

  #: () -> void
  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::INFO
    @storage_registry = {}
  end

  #: () ?{ (Riffer::Core) -> void } -> void
  def configure(&block)
    yield self if block_given?
  end
end
