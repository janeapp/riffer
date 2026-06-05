# frozen_string_literal: true
# rbs_inline: enabled

require "zeitwerk"

# Riffer is the main module for the Riffer AI framework.
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI",
  "azure_open_ai" => "AzureOpenAI",
  "open_router" => "OpenRouter"
)
loader.setup

module Riffer
  extend self

  # @rbs @config: Riffer::Config?

  # Base error class for Riffer.
  class Error < StandardError; end

  # Raised when invalid arguments are provided.
  class ArgumentError < ::ArgumentError; end

  # Raised when tool parameter validation fails.
  class ValidationError < Error; end

  # Raised when tool execution times out.
  class TimeoutError < Error; end

  # Raised when a tool encounters an expected execution error.
  class ToolExecutionError < Error; end

  # Returns the Riffer configuration.
  #
  #--
  #: () -> Riffer::Config
  def config
    @config ||= Config.new
  end

  # Yields the configuration for block-based setup.
  #
  #   Riffer.configure do |config|
  #     config.openai.api_key = ENV['OPENAI_API_KEY']
  #   end
  #
  #--
  #: () ?{ (Riffer::Config) -> void } -> void
  def configure(&block)
    yield config if block_given?
  end

  # Returns the gem version.
  #--
  #: () -> String
  def version
    VERSION
  end
end
