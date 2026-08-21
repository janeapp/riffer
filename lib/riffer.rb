# frozen_string_literal: true
# rbs_inline: enabled

require "zeitwerk"

# Riffer is the main module for the Riffer AI framework.
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI",
  "azure_open_ai" => "AzureOpenAI",
  "open_router" => "OpenRouter",
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

  # Base error for a file attachment that can't be resolved for the provider.
  class FileError < Error; end

  # Raised when the provider can't accept the file at all.
  class FileUnsupportedError < FileError; end

  # Raised when a download is required but Riffer.config.files.allow_downloads is false.
  class FileDownloadsDisabledError < FileError; end

  # Raised when a message carries more files than Riffer.config.files.max_per_message allows.
  class TooManyFilesError < FileError; end

  # Raised when there's an issue downloading a file
  class FileDownloadError < FileError; end

  # Raised when a file size exceeds Riffer.config.files.max_bytes
  class FileTooLargeError < FileError; end

  # Raised when a downloaded or inline file's sha256 doesn't match.
  class FileChecksumMismatchError < FileError; end

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
  def configure(&)
    yield config if block_given?
  end

  # Returns the gem version.
  #--
  #: () -> String
  def version
    VERSION
  end
end
