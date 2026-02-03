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

  # Token usage data for this response.
  #
  # Returns Riffer::Usage or nil.
  attr_reader :usage

  # Creates a new assistant message.
  #
  # content:: String - the message content
  # tool_calls:: Array of Hash - optional tool calls
  # usage:: Riffer::Usage or nil - optional token usage data
  def initialize(content, tool_calls: [], usage: nil)
    super(content)
    @tool_calls = tool_calls
    @usage = usage
  end

  # Returns :assistant.
  def role
    :assistant
  end

  # Converts the message to a hash.
  #
  # Returns Hash with +:role+, +:content+, and optionally +:tool_calls+ and +:usage+.
  def to_h
    hash = {role: role, content: content}
    hash[:tool_calls] = tool_calls unless tool_calls.empty?
    hash[:usage] = usage.to_h if usage
    hash
  end
end
