# frozen_string_literal: true

# Represents a tool execution result in a conversation.
#
#   msg = Riffer::Messages::Tool.new(
#     "The weather is sunny.",
#     tool_call_id: "call_123",
#     name: "weather_tool"
#   )
#   msg.role          # => :tool
#   msg.tool_call_id  # => "call_123"
#   msg.error?        # => false
#
class Riffer::Messages::Tool < Riffer::Messages::Base
  # The ID of the tool call this result responds to.
  #
  # Returns String.
  attr_reader :tool_call_id

  # The name of the tool that was called.
  #
  # Returns String.
  attr_reader :name

  # The error message if the tool execution failed.
  #
  # Returns String or nil.
  attr_reader :error

  # The type of error (:unknown_tool, :validation_error, :execution_error).
  #
  # Returns Symbol or nil.
  attr_reader :error_type

  # Creates a new tool result message.
  #
  # content:: String - the tool execution result
  # tool_call_id:: String - the ID of the tool call
  # name:: String - the tool name
  # error:: String or nil - optional error message
  # error_type:: Symbol or nil - optional error type
  def initialize(content, tool_call_id:, name:, error: nil, error_type: nil)
    super(content)
    @tool_call_id = tool_call_id
    @name = name
    @error = error
    @error_type = error_type
  end

  # Returns true if the tool execution resulted in an error.
  #
  # Returns Boolean.
  def error?
    !@error.nil?
  end

  # Returns :tool.
  def role
    :tool
  end

  # Converts the message to a hash.
  #
  # Returns Hash with message data including error info if present.
  def to_h
    hash = {role: role, content: content, tool_call_id: tool_call_id, name: name}
    if error?
      hash[:error] = error
      hash[:error_type] = error_type
    end
    hash
  end
end
