# frozen_string_literal: true
# rbs_inline: enabled

# Records how long a single guardrail took to execute.
#
# When +Riffer.config.report_timings+ is enabled, the runner measures each
# guardrail's +process_input+/+process_output+ call and produces one Timing per
# guardrail, in execution order.
#
#   timing = Timing.new(
#     guardrail: ProfanityFilter,
#     phase: :before,
#     duration: 0.0012,
#     result_type: :pass
#   )
#   timing.kind        # => :guardrail
#   timing.duration_ms # => 1.2
class Riffer::Guardrails::Timing < Riffer::Timing
  # The guardrail class that was executed.
  attr_reader :guardrail #: singleton(Riffer::Guardrail)

  # The phase when the guardrail ran (:before or :after).
  attr_reader :phase #: Symbol

  # The result the guardrail returned (:pass, :transform, or :block). A
  # guardrail that raises aborts the run before a timing is recorded, so
  # this is always set in practice; it is nilable only as a safe default.
  attr_reader :result_type #: Symbol?

  # Creates a new timing record.
  #
  # [guardrail] the guardrail class that ran.
  # [phase] :before or :after.
  # [duration] execution time in seconds.
  # [result_type] :pass, :transform, or :block.
  #
  #--
  #: (guardrail: singleton(Riffer::Guardrail), phase: Symbol, duration: Float, ?result_type: Symbol?) -> void
  def initialize(guardrail:, phase:, duration:, result_type: nil)
    super(duration: duration)
    @guardrail = guardrail
    @phase = phase
    @result_type = result_type
  end

  # Identifies this as a guardrail timing.
  #
  #--
  #: () -> Symbol
  def kind = :guardrail

  # Converts the timing to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    super.merge(guardrail: guardrail.name, phase: phase, result_type: result_type)
  end
end
