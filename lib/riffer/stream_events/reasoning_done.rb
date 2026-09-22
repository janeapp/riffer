# frozen_string_literal: true
# rbs_inline: enabled

# Represents one completed reasoning block during streaming; only emitted by
# providers that support reasoning (e.g. OpenAI with the reasoning option).
class Riffer::StreamEvents::ReasoningDone < Riffer::StreamEvents::Base
  # The reasoning block, which the agent loop accumulates onto the assistant
  # message. Its +text+ is the content the preceding ReasoningDelta events
  # added up to.
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
