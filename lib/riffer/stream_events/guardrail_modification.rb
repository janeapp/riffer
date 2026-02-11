# frozen_string_literal: true
# rbs_inline: enabled

# Represents a guardrail modification event during streaming.
#
# Emitted when a guardrail transforms data during the streaming pipeline.
class Riffer::StreamEvents::GuardrailModification < Riffer::StreamEvents::Base
  # The modification record.
  attr_reader :modification #: Riffer::Guardrails::Modification

  # Creates a new guardrail modification stream event.
  #
  # +modification+ - the modification details.
  # +role+ - the message role (defaults to :assistant).
  #
  #: (Riffer::Guardrails::Modification, ?role: Symbol) -> void
  def initialize(modification, role: :assistant)
    super(role: role)
    @modification = modification
  end

  # The guardrail class that made the transformation.
  #
  #: () -> singleton(Riffer::Guardrail)
  def guardrail = modification.guardrail

  # The phase when the transformation occurred.
  #
  #: () -> Symbol
  def phase = modification.phase

  # The indices of messages that were changed.
  #
  #: () -> Array[Integer]
  def message_indices = modification.message_indices

  # Converts the event to a hash.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, modification: modification.to_h}
  end
end
