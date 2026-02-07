# frozen_string_literal: true
# rbs_inline: enabled

require "zeitwerk"

# Riffer is the main module for the Riffer AI framework.
#
# Provides configuration, error classes, and versioning for the gem.
#
# See Riffer::Config, Riffer::Agent, Riffer::Providers, and Riffer::Messages.
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI"
)
loader.setup

module Riffer
  # Base error class for Riffer.
  class Error < StandardError; end

  # Raised when invalid arguments are provided.
  class ArgumentError < ::ArgumentError; end

  # Raised when tool parameter validation fails.
  class ValidationError < Error; end

  # Raised when tool execution times out.
  class TimeoutError < Error; end

  #: return: Riffer::Config
  def self.config
    @config ||= Config.new
  end

  # Yields the configuration for block-based setup.
  #
  #   Riffer.configure do |config|
  #     config.openai.api_key = ENV['OPENAI_API_KEY']
  #   end
  #
  #: &block: (Riffer::Config) -> void
  #: return: void
  def self.configure(&block)
    yield config if block_given?
  end

  #: return: String
  def self.version
    VERSION
  end
end
