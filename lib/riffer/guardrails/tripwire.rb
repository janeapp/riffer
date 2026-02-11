# frozen_string_literal: true
# rbs_inline: enabled

# Captures information about a blocked guardrail execution.
#
# When a guardrail blocks execution, a Tripwire is created to record
# the reason, which guardrail triggered it, and which phase it occurred in.
#
#   tripwire = Tripwire.new(
#     reason: "PII detected in input",
#     guardrail_id: "pii_redactor",
#     phase: :before,
#     metadata: { detected_types: [:email, :phone] }
#   )
class Riffer::Guardrails::Tripwire
  PHASES = Riffer::Guardrails::PHASES #: Array[Symbol]

  # The reason for blocking.
  attr_reader :reason #: String

  # The identifier of the guardrail that triggered the block.
  attr_reader :guardrail_id #: String

  # The phase when the block occurred (:before or :after).
  attr_reader :phase #: Symbol

  # Optional metadata about the block.
  attr_reader :metadata #: Hash[Symbol, untyped]?

  # Creates a new tripwire.
  #
  # +reason+ - the reason for blocking.
  # +guardrail_id+ - identifier of the guardrail that blocked.
  # +phase+ - :before or :after.
  # +metadata+ - optional additional information.
  #
  # Raises Riffer::ArgumentError if the phase is invalid.
  #
  #: (reason: String, guardrail_id: String, phase: Symbol, ?metadata: Hash[Symbol, untyped]?) -> void
  def initialize(reason:, guardrail_id:, phase:, metadata: nil)
    raise Riffer::ArgumentError, "Invalid phase: #{phase}" unless PHASES.include?(phase)

    @reason = reason
    @guardrail_id = guardrail_id
    @phase = phase
    @metadata = metadata
  end

  # Converts the tripwire to a hash.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      reason: reason,
      guardrail_id: guardrail_id,
      phase: phase,
      metadata: metadata
    }
  end
end
