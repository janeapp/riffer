# frozen_string_literal: true
# rbs_inline: enabled

# Represents an interrupt during streaming, fired when a callback throws
# +:riffer_interrupt+.
class Riffer::StreamEvents::Interrupt < Riffer::StreamEvents::Base
  # The reason provided with the interrupt, if any.
  attr_reader :reason #: (String | Symbol)?

  # Call ids of tool_use blocks riffer filled with placeholder results when the
  # interrupt fired (only when history healing is on).
  attr_reader :healed_tool_call_ids #: Array[String]

  #--
  #: (?reason: (String | Symbol)?, ?healed_tool_call_ids: Array[String]) -> void
  def initialize(reason: nil, healed_tool_call_ids: [])
    super(role: :system)
    @reason = reason
    @healed_tool_call_ids = healed_tool_call_ids
  end

  # Converts the event to a hash.
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    h = {role: @role, interrupt: true} #: Hash[Symbol, untyped]
    h[:reason] = @reason if @reason
    h[:healed_tool_call_ids] = @healed_tool_call_ids unless @healed_tool_call_ids.empty?
    h
  end
end
