# frozen_string_literal: true
# rbs_inline: enabled

# Represents an assistant (LLM) message in a conversation; may include tool
# calls when the LLM requests tool execution.
class Riffer::Messages::Assistant < Riffer::Messages::Base
  # The reasoning part types +reasoning_text+ reads; the rest carry no prose.
  REASONING_TEXT_TYPES = %i[text summary].freeze #: Array[Symbol]

  # Builds an Assistant message from a hash, or returns +msg+ unchanged when it
  # is already an Assistant message. Raises Riffer::ArgumentError on an invalid
  # tool call, reasoning part, or +finish_reason+.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant)) -> Riffer::Messages::Assistant
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::Assistant)

    new(
      msg[:content],
      id: msg[:id],
      tool_calls: (msg[:tool_calls] || []).map { |tc| Riffer::Messages::Assistant::ToolCall.from_hash(tc) },
      reasoning: (msg[:reasoning] || []).map { |part| Riffer::Messages::Assistant::ReasoningPart.from_hash(part) },
      token_usage: msg[:token_usage] && Riffer::Providers::TokenUsage.from_hash(msg[:token_usage]),
      structured_output: msg[:structured_output],
      finish_reason: msg[:finish_reason]&.to_sym,
      finish_reason_raw: msg[:finish_reason_raw],
    )
  end

  # Array of tool calls requested by the assistant.
  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall] # @dynamic tool_calls

  # The model's reasoning blocks for this response, in the order the provider
  # emitted them.
  attr_reader :reasoning #: Array[Riffer::Messages::Assistant::ReasoningPart] # @dynamic reasoning

  # Token usage data for this response.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage

  # Parsed structured output hash, or nil when not applicable.
  attr_reader :structured_output #: Hash[Symbol, untyped]? # @dynamic structured_output

  # Normalized reason the provider finished this response, when reported (see
  # <tt>Riffer::Providers::FinishReason::VALUES</tt>).
  attr_reader :finish_reason #: Symbol? # @dynamic finish_reason

  # The provider's raw finish-reason value behind +finish_reason+, when one
  # exists on the wire.
  attr_reader :finish_reason_raw #: String? # @dynamic finish_reason_raw

  # Raises Riffer::ArgumentError when +finish_reason+ is outside the
  # normalized vocabulary.
  #--
  #: (
  #    String,
  #    ?id: String?,
  #    ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall],
  #    ?reasoning: Array[Riffer::Messages::Assistant::ReasoningPart],
  #    ?token_usage: Riffer::Providers::TokenUsage?,
  #    ?structured_output: Hash[Symbol, untyped]?,
  #    ?finish_reason: Symbol?,
  #    ?finish_reason_raw: String?
  #  ) -> void
  def initialize(
    content,
    id: nil,
    tool_calls: [],
    reasoning: [],
    token_usage: nil,
    structured_output: nil,
    finish_reason: nil,
    finish_reason_raw: nil
  )
    if finish_reason && !Riffer::Providers::FinishReason::VALUES.include?(finish_reason)
      values = Riffer::Providers::FinishReason::VALUES.inspect
      raise Riffer::ArgumentError, "finish_reason must be one of #{values}, got #{finish_reason.inspect}"
    end

    super(content, id: id)
    @tool_calls = tool_calls
    @reasoning = reasoning
    @token_usage = token_usage
    @structured_output = structured_output
    @finish_reason = finish_reason
    @finish_reason_raw = finish_reason_raw
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
  #: () -> bool
  def reasoning?
    !@reasoning.empty?
  end

  # The readable reasoning across this message's +:text+ and +:summary+ parts,
  # joined by blank lines, or nil when it carries none.
  #--
  #: () -> String?
  def reasoning_text
    texts = reasoning.filter_map { |part| part.text if REASONING_TEXT_TYPES.include?(part.type) }
    texts.empty? ? nil : texts.join("\n\n")
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

  # Converts the message to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: role, content: content } #: Hash[Symbol, untyped]
    hash[:id] = id if id
    hash[:tool_calls] = tool_calls.map(&:to_h) unless tool_calls.empty?
    hash[:reasoning] = reasoning.map(&:to_h) if reasoning?
    hash[:token_usage] = token_usage.to_h if token_usage
    hash[:structured_output] = structured_output if structured_output?
    hash[:finish_reason] = finish_reason if finish_reason
    hash[:finish_reason_raw] = finish_reason_raw if finish_reason_raw
    hash
  end
end
