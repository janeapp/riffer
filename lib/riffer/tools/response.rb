# frozen_string_literal: true

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
  VALID_FORMATS = %i[text json].freeze

  attr_reader :content, :error_message, :error_type

  # Creates a success response.
  #
  # result:: Object - the tool result
  # format:: Symbol - the format (:text or :json; default: :text)
  #
  # Returns Riffer::Tools::Response.
  #
  # Raises Riffer::ArgumentError if format is invalid.
  def self.success(result, format: :text)
    unless VALID_FORMATS.include?(format)
      raise Riffer::ArgumentError, "Invalid format: #{format}. Must be one of: #{VALID_FORMATS.join(", ")}"
    end

    content = (format == :json) ? result.to_json : result.to_s
    new(content: content, success: true)
  end

  # Creates a success response with text format.
  #
  # result:: Object - the tool result (converted via to_s)
  #
  # Returns Riffer::Tools::Response.
  def self.text(result)
    success(result, format: :text)
  end

  # Creates a success response with JSON format.
  #
  # result:: Object - the tool result (converted via to_json)
  #
  # Returns Riffer::Tools::Response.
  def self.json(result)
    success(result, format: :json)
  end

  # Creates an error response.
  #
  # message:: String - the error message
  # type:: Symbol - the error type (default: :execution_error)
  #
  # Returns Riffer::Tools::Response.
  def self.error(message, type: :execution_error)
    new(content: message, success: false, error_message: message, error_type: type)
  end

  # Returns true if the response is successful.
  def success? = @success

  # Returns true if the response is an error.
  def error? = !@success

  # Returns a hash representation of the response.
  #
  # Returns Hash with :content, :error, and :error_type keys.
  def to_h
    {content: @content, error: @error_message, error_type: @error_type}
  end

  private

  def initialize(content:, success:, error_message: nil, error_type: nil)
    @content = content
    @success = success
    @error_message = error_message
    @error_type = error_type
  end
end
