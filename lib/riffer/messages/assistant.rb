# frozen_string_literal: true

# Represents an assistant (LLM) message in a conversation.
#
# May include tool calls when the LLM requests tool execution.
#
#   msg = Riffer::Messages::Assistant.new("Hello!")
#   msg.role        # => :assistant
#   msg.content     # => "Hello!"
#   msg.tool_calls  # => []
#
class Riffer::Messages::Assistant < Riffer::Messages::Base
  # Array of tool calls requested by the assistant.
  #
  # Each tool call is a Hash with +:id+, +:call_id+, +:name+, and +:arguments+ keys.
  #
  # Returns Array of Hash.
  attr_reader :tool_calls

  # Creates a new assistant message.
  #
  # content:: String - the message content
  # tool_calls:: Array of Hash - optional tool calls
  def initialize(content, tool_calls: [])
    super(content)
    @tool_calls = tool_calls
  end

  # Returns :assistant.
  def role
    :assistant
  end

  # Converts the message to a hash.
  #
  # Returns Hash with +:role+, +:content+, and optionally +:tool_calls+.
  def to_h
    hash = {role: role, content: content}
    hash[:tool_calls] = tool_calls unless tool_calls.empty?
    hash
  end
end
