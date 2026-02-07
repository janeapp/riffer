# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::Tools::Response represents the result of a tool execution.
#
# All tools must return a Response object from their +call+ method.
# Use +Response.success+ for successful results and +Response.error+ for failures.
#
#   class MyTool < Riffer::Tool
#     def call(context:, **kwargs)
#       result = perform_operation
#       Riffer::Tools::Response.success(result)
#     rescue MyError => e
#       Riffer::Tools::Response.error(e.message)
#     end
#   end
#
class Riffer::Tools::Response
  VALID_FORMATS = %i[text json].freeze #: Array[Symbol]

  attr_reader :content #: String
  attr_reader :error_message #: String?
  attr_reader :error_type #: Symbol?

  # Creates a success response.
  #
  # Raises Riffer::ArgumentError if format is invalid.
  #
  #: result: untyped -- the tool result
  #: format: Symbol -- the format (:text or :json; default: :text)
  #: return: Riffer::Tools::Response
  def self.success(result, format: :text)
    unless VALID_FORMATS.include?(format)
      raise Riffer::ArgumentError, "Invalid format: #{format}. Must be one of: #{VALID_FORMATS.join(", ")}"
    end

    content = (format == :json) ? result.to_json : result.to_s
    new(content: content, success: true)
  end

  # Creates a success response with text format.
  #
  #: result: untyped -- the tool result (converted via to_s)
  #: return: Riffer::Tools::Response
  def self.text(result)
    success(result, format: :text)
  end

  # Creates a success response with JSON format.
  #
  #: result: untyped -- the tool result (converted via to_json)
  #: return: Riffer::Tools::Response
  def self.json(result)
    success(result, format: :json)
  end

  # Creates an error response.
  #
  #: message: String -- the error message
  #: type: Symbol -- the error type (default: :execution_error)
  #: return: Riffer::Tools::Response
  def self.error(message, type: :execution_error)
    new(content: message, success: false, error_message: message, error_type: type)
  end

  #: return: bool
  def success? = @success

  #: return: bool
  def error? = !@success

  # Returns a hash representation of the response.
  #
  #: return: Hash[Symbol, untyped]
  def to_h
    {content: @content, error: @error_message, error_type: @error_type}
  end

  private

  #: content: String
  #: success: bool
  #: error_message: String?
  #: error_type: Symbol?
  #: return: void
  def initialize(content:, success:, error_message: nil, error_type: nil)
    @content = content
    @success = success
    @error_message = error_message
    @error_type = error_type
  end
end
