# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::ReasoningDone < Riffer::StreamEvents::Base
  # +text+ is the concatenation of the preceding ReasoningDelta events.
  attr_reader :part #: Riffer::Messages::Assistant::ReasoningPart # @dynamic part

  #--
  #: (Riffer::Messages::Assistant::ReasoningPart, ?role: Symbol) -> void
  def initialize(part, role: :assistant)
    super(role: role)
    @part = part
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, part: part.to_h }
  end
end
