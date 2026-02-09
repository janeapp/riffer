# frozen_string_literal: true
# rbs_inline: enabled

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
  ToolCall = Struct.new(:id, :call_id, :name, :arguments, keyword_init: true)

  # Array of tool calls requested by the assistant.
  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall]

  # Token usage data for this response.
  attr_reader :token_usage #: Riffer::TokenUsage?

  #: content: String
  #: tool_calls: Array[Riffer::Messages::Assistant::ToolCall] -- optional tool calls
  #: token_usage: Riffer::TokenUsage? -- optional token usage data
  #: return: void
  def initialize(content, tool_calls: [], token_usage: nil)
    super(content)
    @tool_calls = tool_calls
    @token_usage = token_usage
  end

  #: return: Symbol
  def role
    :assistant
  end

  # Converts the message to a hash.
  #
  #: return: Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content}
    hash[:tool_calls] = tool_calls.map(&:to_h) unless tool_calls.empty?
    hash[:token_usage] = token_usage.to_h if token_usage
    hash
  end
end
