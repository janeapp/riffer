# frozen_string_literal: true
# rbs_inline: enabled

# Records a guardrail transformation event.
class Riffer::Guardrails::Modification
  # The guardrail class that transformed data.
  attr_reader :guardrail #: singleton(Riffer::Guardrail)

  # The phase when the transformation occurred (:before or :after).
  attr_reader :phase #: Symbol

  # The indices of messages that were changed.
  attr_reader :message_indices #: Array[Integer]

  #--
  #: (guardrail: singleton(Riffer::Guardrail), phase: Symbol, message_indices: Array[Integer]) -> void
  def initialize(guardrail:, phase:, message_indices:)
    @guardrail = guardrail
    @phase = phase
    @message_indices = message_indices
  end

  # Converts the modification to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      guardrail: guardrail.name,
      phase: phase,
      message_indices: message_indices,
    }
  end
end
