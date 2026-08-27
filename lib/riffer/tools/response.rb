# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Represents the result of a tool execution; every tool's +call+ must return one.
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
  # @rbs @success: bool

  VALID_FORMATS = %i[text json].freeze #: Array[Symbol]

  # The response content.
  attr_reader :content #: String

  # The error message, or +nil+ on success.
  attr_reader :error_message #: String?

  # The error type, or +nil+ on success.
  attr_reader :error_type #: Symbol?

  # The exception an unhandled failure was folded from, or +nil+. Kept out of
  # every serialized form so it never reaches an LLM or a message payload.
  attr_reader :exception #: Exception?

  # Creates a success response.
  #
  # Raises Riffer::ArgumentError if format is invalid.
  #
  #--
  #: (untyped, ?format: Symbol) -> Riffer::Tools::Response
  def self.success(result, format: :text)
    unless VALID_FORMATS.include?(format)
      raise Riffer::ArgumentError, "Invalid format: #{format}. Must be one of: #{VALID_FORMATS.join(', ')}"
    end

    content = format == :json ? result.to_json : result.to_s
    new(content: content, success: true)
  end

  # Creates a success response with text format.
  #
  #--
  #: (untyped) -> Riffer::Tools::Response
  def self.text(result)
    success(result, format: :text)
  end

  # Creates a success response with JSON format.
  #
  #--
  #: (untyped) -> Riffer::Tools::Response
  def self.json(result)
    success(result, format: :json)
  end

  # Creates an error response.
  #
  #--
  #: (String, ?type: Symbol, ?exception: Exception?) -> Riffer::Tools::Response
  def self.error(message, type: :execution_error, exception: nil)
    new(content: message, success: false, error_message: message, error_type: type, exception: exception)
  end

  # Returns true if the tool execution succeeded.
  #--
  #: () -> bool
  def success? = @success

  # Returns true if the tool execution failed.
  #--
  #: () -> bool
  def error? = !@success

  # Returns a hash representation of the response.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { content: @content, error: @error_message, error_type: @error_type }
  end

  private

  #--
  #: (content: String, success: bool, ?error_message: String?, ?error_type: Symbol?, ?exception: Exception?) -> void
  def initialize(content:, success:, error_message: nil, error_type: nil, exception: nil)
    @content = content
    @success = success
    @error_message = error_message
    @error_type = error_type
    @exception = exception
  end
end
