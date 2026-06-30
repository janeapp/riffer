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
  #: (guardrail: String, phase: Symbol, duration: Float, ?outcome: Symbol?, ?error_type: String?, ?error: Exception?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(guardrail:, phase:, duration:, outcome: nil, error_type: nil, error: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error_type: error_type, error: error, tags: tags, trace_id: trace_id, span_id: span_id)
    @guardrail = guardrail
    @phase = phase
    @outcome = outcome
  end

  # The operation identifier.
  #--
  #: () -> Symbol
  def operation = :execute_guardrail

  # The dotted event name.
  #--
  #: () -> String
  def name = "riffer.execute_guardrail"
end
