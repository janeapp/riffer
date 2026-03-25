# frozen_string_literal: true
# rbs_inline: enabled

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI",
  "azure_open_ai" => "AzureOpenAI"
)
loader.setup

module Riffer
  class Error < StandardError; end

  class ArgumentError < ::ArgumentError; end

  class ValidationError < Error; end

  class TimeoutError < Error; end

  class ToolExecutionError < Error; end

  #: () -> Riffer::Config
  def self.config
    @config ||= Config.new
  end

  #: () ?{ (Riffer::Config) -> void } -> void
  def self.configure(&block)
    yield config if block_given?
  end

  #: () -> String
  def self.version
    VERSION
  end
end
