# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Tools::Response
  VALID_FORMATS = %i[text json].freeze #: Array[Symbol]

  attr_reader :content #: String
  attr_reader :error_message #: String?
  attr_reader :error_type #: Symbol?

  #: (untyped, ?format: Symbol) -> Riffer::Tools::Response
  def self.success(result, format: :text)
    unless VALID_FORMATS.include?(format)
      raise Riffer::ArgumentError, "Invalid format: #{format}. Must be one of: #{VALID_FORMATS.join(", ")}"
    end

    content = (format == :json) ? result.to_json : result.to_s
    new(content: content, success: true)
  end

  #: (untyped) -> Riffer::Tools::Response
  def self.text(result)
    success(result, format: :text)
  end

  #: (untyped) -> Riffer::Tools::Response
  def self.json(result)
    success(result, format: :json)
  end

  #: (String, ?type: Symbol) -> Riffer::Tools::Response
  def self.error(message, type: :execution_error)
    new(content: message, success: false, error_message: message, error_type: type)
  end

  #: () -> bool
  def success? = @success

  #: () -> bool
  def error? = !@success

  #: () -> Hash[Symbol, untyped]
  def to_h
    {content: @content, error: @error_message, error_type: @error_type}
  end

  private

  #: (content: String, success: bool, ?error_message: String?, ?error_type: Symbol?) -> void
  def initialize(content:, success:, error_message: nil, error_type: nil)
    @content = content
    @success = success
    @error_message = error_message
    @error_type = error_type
  end
end
