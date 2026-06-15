# frozen_string_literal: true
# rbs_inline: enabled

# Represents an assistant (LLM) message in a conversation; may include tool
# calls when the LLM requests tool execution.
class Riffer::Messages::Assistant < Riffer::Messages::Base
  ToolCall = Struct.new(:call_id, :name, :arguments)

  # Array of tool calls requested by the assistant.
  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall]

  # Token usage data for this response.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  # Parsed structured output hash, or nil when not applicable.
  attr_reader :structured_output #: Hash[Symbol, untyped]?

  # Normalized reason the provider finished this response, when reported (see
  # <tt>Riffer::Providers::FinishReason::VALUES</tt>).
  attr_reader :finish_reason #: Symbol?

  # Raises Riffer::ArgumentError when +finish_reason+ is outside the
  # normalized vocabulary.
  #--
  #: (String, ?id: String?, ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall], ?token_usage: Riffer::Providers::TokenUsage?, ?structured_output: Hash[Symbol, untyped]?, ?finish_reason: Symbol?) -> void
  def initialize(content, id: nil, tool_calls: [], token_usage: nil, structured_output: nil, finish_reason: nil)
    if finish_reason && !Riffer::Providers::FinishReason::VALUES.include?(finish_reason)
      raise Riffer::ArgumentError, "finish_reason must be one of #{Riffer::Providers::FinishReason::VALUES.inspect}, got #{finish_reason.inspect}"
    end

    super(content, id: id)
    @tool_calls = tool_calls
    @token_usage = token_usage
    @structured_output = structured_output
    @finish_reason = finish_reason
  end

  #--
  #: () -> Symbol
  def role
    :assistant
  end

  #--
  #: () -> bool
  def structured_output?
    !@structured_output.nil?
  end

  #--
  #: () -> bool
  def has_tool_calls?
    !@tool_calls.empty?
  end

  #--
  #: (Riffer::Messages::Assistant) -> Riffer::Messages::Assistant
  def +(other)
    self.class.new("#{content}\n\n#{other.content}", tool_calls: tool_calls + other.tool_calls)
  end

  # Converts the message to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {role: role, content: content} #: Hash[Symbol, untyped]
    hash[:id] = id unless id.nil?
    hash[:tool_calls] = tool_calls.map(&:to_h) unless tool_calls.empty?
    hash[:token_usage] = token_usage.to_h if token_usage
    hash[:structured_output] = structured_output if structured_output?
    hash[:finish_reason] = finish_reason if finish_reason
    hash
  end
end
