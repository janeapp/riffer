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
    #: (Integer) -> singleton(Riffer::APIError)
    def self.for_status(status)
      case status
      when 429 then RateLimitError
      when 529 then OverloadedError
      when 401, 403 then AuthenticationError
      when 400..499 then InvalidRequestError
      when 500..599 then ServerError
      else APIError
      end
    end

    # +type+ is the +error.type+ of a Messages API stream +error+ event.
    #--
    #: (String?) -> singleton(Riffer::APIError)
    def self.for_stream_error_type(type)
      case type
      when "rate_limit_error" then RateLimitError
      when "overloaded_error" then OverloadedError
      when "api_error", "timeout_error" then ServerError
      when "authentication_error", "permission_error" then AuthenticationError
      when "invalid_request_error", "not_found_error", "request_too_large" then InvalidRequestError
      else APIError
      end
    end

    #--
    #: (?String?, ?status: Integer?, ?body: String?) -> void
    def initialize(message = nil, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class RateLimitError < APIError; end

  class OverloadedError < APIError; end

  class ServerError < APIError; end

  class AuthenticationError < APIError; end

  class InvalidRequestError < APIError; end

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

  class DeprecationError < Error; end

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
