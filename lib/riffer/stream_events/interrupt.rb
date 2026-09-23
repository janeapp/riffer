# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::Interrupt < Riffer::StreamEvents::Base
  attr_reader :reason #: (String | Symbol)? # @dynamic reason

  # Tool calls given placeholder results; empty unless history healing is on.
  attr_reader :healed_tool_call_ids #: Array[String] # @dynamic healed_tool_call_ids

  #--
  #: (?reason: (String | Symbol)?, ?healed_tool_call_ids: Array[String]) -> void
  def initialize(reason: nil, healed_tool_call_ids: [])
    super(role: :system)
    @reason = reason
    @healed_tool_call_ids = healed_tool_call_ids
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    h = { role: @role, interrupt: true } #: Hash[Symbol, untyped]
    h[:reason] = @reason if @reason
    h[:healed_tool_call_ids] = @healed_tool_call_ids unless @healed_tool_call_ids.empty?
    h
  end
end
