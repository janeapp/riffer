# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Guardrails::Tripwire
  PHASES = Riffer::Guardrails::PHASES #: Array[Symbol]

  attr_reader :reason #: String

  attr_reader :guardrail #: singleton(Riffer::Guardrail)

  attr_reader :phase #: Symbol

  attr_reader :metadata #: Hash[Symbol, untyped]?

  #: (reason: String, guardrail: singleton(Riffer::Guardrail), phase: Symbol, ?metadata: Hash[Symbol, untyped]?) -> void
  def initialize(reason:, guardrail:, phase:, metadata: nil)
    raise Riffer::ArgumentError, "Invalid phase: #{phase}" unless PHASES.include?(phase)

    @reason = reason
    @guardrail = guardrail
    @phase = phase
    @metadata = metadata
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      reason: reason,
      guardrail: guardrail.name,
      phase: phase,
      metadata: metadata
    }
  end
end
