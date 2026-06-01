# frozen_string_literal: true
# rbs_inline: enabled

# Base class for execution timings.
#
# When +Riffer.config.report_timings+ is enabled, the framework measures how
# long individual units of work take and produces one Timing per unit —
# guardrails, tool calls, and LLM calls — exposed together, in execution order,
# on Riffer::Agent::Response#timings (and, when streaming, as
# Riffer::StreamEvents::Timing events).
#
# Every timing carries a +kind+ (use it to discriminate) and a +duration+ in
# seconds, measured with a monotonic clock. Each subclass adds the fields
# relevant to its unit of work.
class Riffer::Timing
  # The wall-clock execution time, in seconds, measured with a monotonic clock.
  attr_reader :duration #: Float

  #--
  #: (duration: Float) -> void
  def initialize(duration:)
    @duration = duration
  end

  # A symbol identifying the kind of unit this timing describes (e.g.
  # +:guardrail+, +:tool+, +:llm+). Implemented by each subclass.
  #
  #--
  #: () -> Symbol
  def kind
    raise NotImplementedError, "#{self.class} must implement #kind"
  end

  # The execution time in milliseconds.
  #
  #--
  #: () -> Float
  def duration_ms
    duration * 1000.0
  end

  # Converts the timing to a hash. Subclasses merge their own fields onto this
  # +kind+/+duration+ core.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {kind: kind, duration: duration}
  end
end
