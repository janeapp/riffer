# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::Assistant < Riffer::Messages::Base
  # The other reasoning part types carry no prose.
  REASONING_TEXT_TYPES = %i[text summary].freeze #: Array[Symbol]

  PART_TAGS = {
    Riffer::Messages::Assistant::TextPart => :text,
    Riffer::Messages::Assistant::ReasoningPart => :reasoning,
    Riffer::Messages::Assistant::ToolCall => :tool_call,
    Riffer::Messages::Assistant::ServerToolPart => :server_tool,
  }.freeze #: Hash[singleton(Riffer::Messages::Assistant::TextPart) | singleton(Riffer::Messages::Assistant::ReasoningPart) | singleton(Riffer::Messages::Assistant::ToolCall) | singleton(Riffer::Messages::Assistant::ServerToolPart), Symbol]

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant)) -> Riffer::Messages::Assistant
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::Assistant)

    options = {
      id: msg[:id],
      token_usage: msg[:token_usage] && Riffer::Providers::TokenUsage.from_hash(msg[:token_usage]),
      structured_output: msg[:structured_output],
      finish_reason: msg[:finish_reason]&.to_sym,
      finish_reason_raw: msg[:finish_reason_raw],
    } #: Hash[Symbol, untyped]

    new(
      msg[:content],
      parts: msg[:parts]&.map { |part| part_from_hash(part) },
      tool_calls: (msg[:tool_calls] || []).map { |tc| Riffer::Messages::Assistant::ToolCall.from_hash(tc) },
      reasoning: (msg[:reasoning] || []).map { |part| Riffer::Messages::Assistant::ReasoningPart.from_hash(part) },
      **options,
    )
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart)) -> (Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart)
  def self.part_from_hash(part)
    return part unless part.is_a?(Hash)

    klass = PART_TAGS.key(part[:part]&.to_sym)
    unless klass
      raise Riffer::ArgumentError, "part must be one of #{PART_TAGS.values.inspect}, got #{part[:part].inspect}"
    end

    klass.from_hash(part.except(:part))
  end
  private_class_method :part_from_hash

  # The turn in the order the provider produced it. +content+, +tool_calls+ and +reasoning+ are
  # views over it.
  attr_reader :parts #: Array[Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart] # @dynamic parts

  attr_reader :tool_calls #: Array[Riffer::Messages::Assistant::ToolCall] # @dynamic tool_calls

  attr_reader :reasoning #: Array[Riffer::Messages::Assistant::ReasoningPart] # @dynamic reasoning

  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage

  attr_reader :structured_output #: Hash[Symbol, untyped]? # @dynamic structured_output

  attr_reader :finish_reason #: Symbol? # @dynamic finish_reason

  attr_reader :finish_reason_raw #: String? # @dynamic finish_reason_raw

  # Without +parts:+, the parts are built in a fixed order: reasoning, then the content as one
  # text part, then tool calls.
  #--
  #: (?String?, ?id: String?, ?parts: Array[Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart]?, ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall], ?reasoning: Array[Riffer::Messages::Assistant::ReasoningPart], ?token_usage: Riffer::Providers::TokenUsage?, ?structured_output: Hash[Symbol, untyped]?, ?finish_reason: Symbol?, ?finish_reason_raw: String?) -> void
  def initialize(
    content = nil,
    id: nil,
    parts: nil,
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

    if parts && (content || !tool_calls.empty? || !reasoning.empty?)
      raise Riffer::ArgumentError, "pass either parts: or content, tool_calls: and reasoning:, not both"
    end

    @parts = parts || default_parts(content, tool_calls, reasoning)
    super(@parts.filter_map { |part| part.text if part.is_a?(Riffer::Messages::Assistant::TextPart) }.join, id: id)
    @tool_calls = @parts.grep(Riffer::Messages::Assistant::ToolCall) #: Array[Riffer::Messages::Assistant::ToolCall]
    @reasoning = @parts.grep(Riffer::Messages::Assistant::ReasoningPart) #: Array[Riffer::Messages::Assistant::ReasoningPart]
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

  #--
  #: () -> String?
  def reasoning_text
    texts = reasoning.filter_map { |part| part.text if REASONING_TEXT_TYPES.include?(part.type) }
    texts.empty? ? nil : texts.join("\n\n")
  end

  #--
  #: (Riffer::Messages::Assistant) -> Riffer::Messages::Assistant
  def +(other)
    unless [self, other].all? { |message| described_by_fields?(message) }
      merged = parts.dup
      merged << Riffer::Messages::Assistant::TextPart.new("\n\n") unless content.empty? || other.content.empty?
      return self.class.new(parts: merged.concat(other.parts))
    end

    self.class.new(
      "#{content}\n\n#{other.content}",
      tool_calls: tool_calls + other.tool_calls,
      reasoning: reasoning + other.reasoning,
    )
  end

  # The default shape writes +content+, +tool_calls+ and +reasoning+ in the fixed order, which
  # drops server tool parts and the +data+ of text parts. <tt>parts: true</tt> writes +parts+
  # instead of those three.
  #--
  #: (?parts: bool) -> Hash[Symbol, untyped]
  def to_h(parts: false)
    hash = { role: role } #: Hash[Symbol, untyped]
    if parts
      hash[:id] = id if id
      hash[:parts] = @parts.map { |part| { part: PART_TAGS.fetch(part.class), **part.to_h } }
    else
      hash[:content] = content
      hash[:id] = id if id
      hash[:tool_calls] = tool_calls.map(&:to_h) unless tool_calls.empty?
      hash[:reasoning] = reasoning.map(&:to_h) if reasoning?
    end
    hash[:token_usage] = token_usage.to_h if token_usage
    hash[:structured_output] = structured_output if structured_output?
    hash[:finish_reason] = finish_reason if finish_reason
    hash[:finish_reason_raw] = finish_reason_raw if finish_reason_raw
    hash
  end

  private

  #--
  #: (String?, Array[Riffer::Messages::Assistant::ToolCall], Array[Riffer::Messages::Assistant::ReasoningPart]) -> Array[Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart]
  def default_parts(content, tool_calls, reasoning)
    parts = [] #: Array[Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart]
    parts.concat(reasoning)
    parts << Riffer::Messages::Assistant::TextPart.new(content) unless content.nil? || content.empty?
    parts.concat(tool_calls)
  end

  #--
  #: (Riffer::Messages::Assistant) -> bool
  def described_by_fields?(message)
    message.parts == default_parts(message.content, message.tool_calls, message.reasoning)
  end
end
