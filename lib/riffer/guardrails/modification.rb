# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Guardrails::Modification
  attr_reader :guardrail #: singleton(Riffer::Guardrail)

  attr_reader :phase #: Symbol

  attr_reader :message_indices #: Array[Integer]

  #: (guardrail: singleton(Riffer::Guardrail), phase: Symbol, message_indices: Array[Integer]) -> void
  def initialize(guardrail:, phase:, message_indices:)
    @guardrail = guardrail
    @phase = phase
    @message_indices = message_indices
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      guardrail: guardrail.name,
      phase: phase,
      message_indices: message_indices
    }
  end
end
