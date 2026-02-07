# frozen_string_literal: true
# rbs_inline: enabled

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
  attr_reader :tool_call_id #: String

  # The name of the tool that was called.
  attr_reader :name #: String

  # The error message if the tool execution failed.
  attr_reader :error #: String?

  # The type of error (:unknown_tool, :validation_error, :execution_error, :timeout_error).
  attr_reader :error_type #: Symbol?

  #: content: String -- the tool execution result
  #: tool_call_id: String -- the ID of the tool call
  #: name: String -- the tool name
  #: error: String? -- optional error message
  #: error_type: Symbol? -- optional error type
  #: return: void
  def initialize(content, tool_call_id:, name:, error: nil, error_type: nil)
    super(content)
    @tool_call_id = tool_call_id
    @name = name
    @error = error
    @error_type = error_type
  end

  # Returns true if the tool execution resulted in an error.
  #
  #: return: bool
  def error?
    !@error.nil?
  end

  #: return: Symbol
  def role
    :tool
  end

  # Converts the message to a hash.
  #
  #: return: Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content, tool_call_id: tool_call_id, name: name}
    if error?
      hash[:error] = error
      hash[:error_type] = error_type
    end
    hash
  end
end
