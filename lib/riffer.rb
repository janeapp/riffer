# frozen_string_literal: true
# rbs_inline: enabled

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI",
  "azure_open_ai" => "AzureOpenAI",
  "open_router" => "OpenRouter",
)
# Test-framework wiring a consumer requires by hand; neither file defines the
# constant its path implies, and both reference framework constants riffer
# never loads itself.
loader.ignore(
  "#{__dir__}/riffer/testing/rspec.rb",
  "#{__dir__}/riffer/testing/minitest.rb",
)
loader.setup

module Riffer
  extend self

  # @rbs @config: Riffer::Config?

  class Error < StandardError; end

  class ArgumentError < ::ArgumentError; end

  class ValidationError < Error; end

  # Rescue it in the tool to clean up; otherwise it becomes a
  # +:timeout_error+ response.
  class TimeoutError < Error; end

  class ToolExecutionError < Error; end

  # Events already yielded were delivered; the request is safe to retry.
  class IncompleteStreamError < Error; end

  class FileError < Error; end

  class FileUnsupportedError < FileError; end

  class FileDownloadsDisabledError < FileError; end

  class TooManyFilesError < FileError; end

  class FileDownloadError < FileError; end

  class FileTooLargeError < FileError; end

  class FileChecksumMismatchError < FileError; end

  class FileEncodingError < FileError; end

  class DuplicateIdentifierError < Error; end

  #--
  #: () -> Riffer::Config
  def config
    @config ||= Config.new
  end

  #   Riffer.configure do |config|
  #     config.openai.api_key = ENV['OPENAI_API_KEY']
  #   end
  #
  #--
  #: () ?{ (Riffer::Config) -> void } -> void
  def configure(&)
    yield config if block_given?
  end

  #--
  #: () -> String
  def version
    VERSION
  end
end
