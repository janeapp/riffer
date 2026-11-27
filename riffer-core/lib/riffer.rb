# frozen_string_literal: true
# rbs_inline: enabled

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI",
  "azure_open_ai" => "AzureOpenAI",
  "open_router" => "OpenRouter",
  "sse" => "SSE",
  "http" => "HTTP",
  "messages_api" => "MessagesAPI",
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

  # A provider answered with a non-success status, or sent an in-stream error
  # event (+status+ is nil then). +body+ is the raw response text.
  class APIError < Error
    attr_reader :status #: Integer? # @dynamic status
    attr_reader :body #: String? # @dynamic body

    #--
    #: (?String?, ?status: Integer?, ?body: String?) -> void
    def initialize(message = nil, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

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

  class FileDataMissingError < FileError; end

  class DuplicateIdentifierError < Error; end

  class DeprecationError < Error; end

  # Taken off Riffer so that referencing one goes through const_missing, which
  # reports the deprecation. Ruby's deprecate_constant only warns when
  # Warning[:deprecated] is on. Removing the constant keeps the class's name.
  DEPRECATED_FILE_ERRORS = %i[TooManyFilesError FileTooLargeError FileChecksumMismatchError].
    to_h { |name| [name, remove_const(name)] }.freeze #: Hash[Symbol, singleton(Riffer::FileError)]
  private_constant :DEPRECATED_FILE_ERRORS

  #--
  #: (Symbol) -> untyped
  def self.const_missing(name)
    return super unless DEPRECATED_FILE_ERRORS.key?(name)

    Riffer::Deprecation.warn(
      id: :file_error_constants,
      message: "Riffer::#{name} is deprecated and will be removed; riffer stops raising it under " \
               "config.future.file_downloads.",
    )
    DEPRECATED_FILE_ERRORS.fetch(name)
  end

  #--
  #: () -> Riffer::Config
  def config
    @config ||= Config.new
  end

  # Builds the catalog after the block, so a bad catalog file fails boot.
  #--
  #: () ?{ (Riffer::Config) -> void } -> void
  def configure(&)
    yield config if block_given?
    config.reload_catalog
  end

  #--
  #: () -> String
  def version
    VERSION
  end
end
