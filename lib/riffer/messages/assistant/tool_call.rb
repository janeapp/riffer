# frozen_string_literal: true
# rbs_inline: enabled

# Represents one tool invocation the model requested on an assistant message.
class Riffer::Messages::Assistant::ToolCall
  # The provider's identifier for the call, echoed back on the tool result.
  attr_reader :call_id #: String # @dynamic call_id

  # The name of the tool to invoke.
  attr_reader :name #: String # @dynamic name

  # The JSON-encoded arguments, exactly as the provider emitted them.
  attr_reader :arguments #: String # @dynamic arguments

  # Builds a ToolCall from a hash, or returns +call+ unchanged when it is
  # already a ToolCall. Raises Riffer::ArgumentError when the hash is missing
  # a field.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant::ToolCall)) -> Riffer::Messages::Assistant::ToolCall
  def self.from_hash(call)
    return call if call.is_a?(Riffer::Messages::Assistant::ToolCall)

    if call.values_at(:call_id, :name, :arguments).any?(&:nil?)
      raise Riffer::ArgumentError, "Tool call hash must include :call_id, :name, and :arguments"
    end

    new(call_id: call[:call_id], name: call[:name], arguments: call[:arguments])
  end

  #--
  #: (call_id: String, name: String, arguments: String) -> void
  def initialize(call_id:, name:, arguments:)
    @call_id = call_id
    @name = name
    @arguments = arguments
  end

  # Serializes the call to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { call_id: call_id, name: name, arguments: arguments }
  end

  #--
  #: (untyped) -> bool
  def ==(other)
    other.is_a?(Riffer::Messages::Assistant::ToolCall) && to_h == other.to_h
  end

  #--
  #: (untyped) -> bool
  def eql?(other)
    self == other
  end

  #--
  #: () -> Integer
  def hash
    to_h.hash
  end
end
