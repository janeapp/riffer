# frozen_string_literal: true
# rbs_inline: enabled

# Published when a guardrail finishes. +outcome+ is the result action; it is
# +nil+ when the guardrail raised, in which case +error_type+ is set.
class Riffer::Events::GuardrailExecuted < Riffer::Events::Base
  # The guardrail identifier.
  attr_reader :guardrail #: String

  # The execution phase, +:before+ or +:after+.
  attr_reader :phase #: Symbol

  # The result action — +:pass+, +:transform+, or +:block+ — or +nil+ when the
  # guardrail raised.
  attr_reader :outcome #: Symbol?

  #--
  #: (guardrail: String, phase: Symbol, duration: Float, ?outcome: Symbol?, ?error: Exception?, ?error_type: String?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(guardrail:, phase:, duration:, outcome: nil, error: nil, error_type: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error: error, error_type: error_type, tags: tags, trace_id: trace_id, span_id: span_id)
    @guardrail = guardrail
    @phase = phase
    @outcome = outcome
  end

  # The dotted event name.
  #--
  #: () -> String
  def name = "riffer.execute_guardrail"

  # Guardrail, phase, and the result action, on top of the shared dimensions.
  #--
  #: () -> Hash[String, String]
  def dimensions
    dims = super
    dims["guardrail"] = guardrail
    dims["phase"] = phase.to_s
    dims["action"] = outcome.to_s if outcome
    dims
  end
end
