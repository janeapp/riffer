# frozen_string_literal: true
# rbs_inline: enabled

# Captures information about a blocked guardrail execution.
class Riffer::Guardrails::Tripwire
  PHASES = Riffer::Guardrails::PHASES #: Array[Symbol]

  # The reason for blocking.
  attr_reader :reason #: String

  # The guardrail class that triggered the block.
  attr_reader :guardrail #: singleton(Riffer::Guardrail)

  # The phase when the block occurred (:before or :after).
  attr_reader :phase #: Symbol

  # Optional metadata about the block.
  attr_reader :metadata #: Hash[Symbol, untyped]?

  # Raises Riffer::ArgumentError if +phase+ is invalid.
  #--
  #: (reason: String, guardrail: singleton(Riffer::Guardrail), phase: Symbol, ?metadata: Hash[Symbol, untyped]?) -> void
  def initialize(reason:, guardrail:, phase:, metadata: nil)
    raise Riffer::ArgumentError, "Invalid phase: #{phase}" unless PHASES.include?(phase)

    @reason = reason
    @guardrail = guardrail
    @phase = phase
    @metadata = metadata
  end

  # Converts the tripwire to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      reason: reason,
      guardrail: guardrail.name,
      phase: phase,
      metadata: metadata,
    }
  end
end
