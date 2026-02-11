# frozen_string_literal: true

# Captures information about a blocked guardrail execution.
#
# When a guardrail blocks execution, a Tripwire is created to record
# the reason, which guardrail triggered it, and which phase it occurred in.
#
#   tripwire = Tripwire.new(
#     reason: "PII detected in input",
#     guardrail_id: "pii_redactor",
#     phase: :input,
#     metadata: { detected_types: [:email, :phone] }
#   )
class Riffer::Guardrails::Tripwire
  PHASES = %i[input output].freeze

  # The reason for blocking.
  #
  # Returns String.
  attr_reader :reason

  # The identifier of the guardrail that triggered the block.
  #
  # Returns String.
  attr_reader :guardrail_id

  # The phase when the block occurred (:input or :output).
  #
  # Returns Symbol.
  attr_reader :phase

  # Optional metadata about the block.
  #
  # Returns Hash or nil.
  attr_reader :metadata

  # Creates a new tripwire.
  #
  # reason:: String - the reason for blocking
  # guardrail_id:: String - identifier of the guardrail that blocked
  # phase:: Symbol - :input or :output
  # metadata:: Hash or nil - optional additional information
  def initialize(reason:, guardrail_id:, phase:, metadata: nil)
    raise Riffer::ArgumentError, "Invalid phase: #{phase}" unless PHASES.include?(phase)

    @reason = reason
    @guardrail_id = guardrail_id
    @phase = phase
    @metadata = metadata
  end

  # Converts the tripwire to a hash.
  #
  # Returns Hash.
  def to_h
    {
      reason: reason,
      guardrail_id: guardrail_id,
      phase: phase,
      metadata: metadata
    }
  end
end
