# frozen_string_literal: true
# rbs_inline: enabled

# Represents an assistant (LLM) message in a conversation; may include tool
# calls when the LLM requests tool execution.
class Riffer::Messages::Assistant < Riffer::Messages::Base
  ToolCall = Struct.new(:call_id, :name, :arguments, :signature) do
    # Omits an absent +signature+, so a tool call from a provider that doesn't
    # sign one serializes to the same hash it always has.
    #--
    #: () -> Hash[Symbol, untyped]
    def to_h
      hash = super
      hash.delete(:signature) if hash[:signature].nil?
      hash
    end
  end

  Reasoning = Struct.new(:text, :signature, :redacted_data, :id)

  # Array of tool calls requested by the assistant.
  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall]

  # Reasoning (thinking) blocks in the order the model produced them.
  # +signature+ is the provider's opaque replay token — an Anthropic or Bedrock
  # thinking signature, OpenAI encrypted reasoning content, a Gemini thought
  # signature — and must be replayed unmodified, so a provider replays only the
  # blocks carrying one (or +redacted_data+); an altered or unsigned block is
  # rejected on the next turn.
  attr_reader :reasoning #: Array[Riffer::Messages::Assistant::Reasoning]

  # Token usage data for this response.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  # Parsed structured output hash, or nil when not applicable.
  attr_reader :structured_output #: Hash[Symbol, untyped]?

  # Normalized reason the provider finished this response, when reported (see
  # <tt>Riffer::Providers::FinishReason::VALUES</tt>).
  attr_reader :finish_reason #: Symbol?

  # The provider's raw finish-reason value behind +finish_reason+, when one
  # exists on the wire.
  attr_reader :finish_reason_raw #: String?

  # Raises Riffer::ArgumentError when +finish_reason+ is outside the
  # normalized vocabulary.
  #--
  #: (
  #    String,
  #    ?id: String?,
  #    ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall],
  #    ?token_usage: Riffer::Providers::TokenUsage?,
  #    ?structured_output: Hash[Symbol, untyped]?,
  #    ?finish_reason: Symbol?,
  #    ?finish_reason_raw: String?,
  #    ?reasoning: Array[Riffer::Messages::Assistant::Reasoning]
  #  ) -> void
  def initialize(
    content,
    id: nil,
    tool_calls: [],
    token_usage: nil,
    structured_output: nil,
    finish_reason: nil,
    finish_reason_raw: nil,
    reasoning: []
  )
    if finish_reason && !Riffer::Providers::FinishReason::VALUES.include?(finish_reason)
      values = Riffer::Providers::FinishReason::VALUES.inspect
      raise Riffer::ArgumentError, "finish_reason must be one of #{values}, got #{finish_reason.inspect}"
    end

    super(content, id: id)
    @tool_calls = tool_calls
    @token_usage = token_usage
    @structured_output = structured_output
    @finish_reason = finish_reason
    @finish_reason_raw = finish_reason_raw
    @reasoning = reasoning
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
    self.class.new(
      "#{content}\n\n#{other.content}",
      tool_calls: tool_calls + other.tool_calls,
      reasoning: reasoning + other.reasoning,
    )
  end

  # Returns a copy with every provider replay token dropped — reasoning
  # signatures and redacted payloads, tool call signatures — keeping the
  # reasoning text and ids. A token is bound to the exact request prefix that
  # produced it, so a provider rejects one replayed under an edited history;
  # every converter skips a block that carries none.
  #--
  #: () -> Riffer::Messages::Assistant
  def without_replay_tokens
    self.class.new(
      content,
      id: id,
      tool_calls: tool_calls.map { |tc| ToolCall.new(tc.call_id, tc.name, tc.arguments, nil) },
      token_usage: token_usage,
      structured_output: structured_output,
      finish_reason: finish_reason,
      finish_reason_raw: finish_reason_raw,
      reasoning: reasoning.map { |r| Reasoning.new(r.text, nil, nil, r.id) },
    )
  end

  # Converts the message to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: role, content: content } #: Hash[Symbol, untyped]
    hash[:id] = id if id
    hash[:tool_calls] = tool_calls.map(&:to_h) unless tool_calls.empty?
    hash[:reasoning] = reasoning.map(&:to_h) unless reasoning.empty?
    hash[:token_usage] = token_usage.to_h if token_usage
    hash[:structured_output] = structured_output if structured_output?
    hash[:finish_reason] = finish_reason if finish_reason
    hash[:finish_reason_raw] = finish_reason_raw if finish_reason_raw
    hash
  end
end
