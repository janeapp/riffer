# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::GuardrailModification < Riffer::StreamEvents::Base
  attr_reader :modification #: Riffer::Guardrails::Modification

  #: (Riffer::Guardrails::Modification, ?role: Symbol) -> void
  def initialize(modification, role: :assistant)
    super(role: role)
    @modification = modification
  end

  #: () -> singleton(Riffer::Guardrail)
  def guardrail = modification.guardrail

  #: () -> Symbol
  def phase = modification.phase

  #: () -> Array[Integer]
  def message_indices = modification.message_indices

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, modification: modification.to_h}
  end
end
