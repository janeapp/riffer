# frozen_string_literal: true
# rbs_inline: enabled

# Represents a timing event during streaming.
#
# Emitted after each timed unit of work — a guardrail, a tool call, or an LLM
# call — when +Riffer.config.report_timings+ is enabled. The wrapped
# Riffer::Timing carries the details; use +kind+ to discriminate.
class Riffer::StreamEvents::Timing < Riffer::StreamEvents::Base
  # The timing record.
  attr_reader :timing #: Riffer::Timing

  # Creates a new timing stream event.
  #
  # [timing] the timing details.
  # [role] the message role (defaults to :assistant).
  #
  #--
  #: (Riffer::Timing, ?role: Symbol) -> void
  def initialize(timing, role: :assistant)
    super(role: role)
    @timing = timing
  end

  # The kind of unit this timing describes (:guardrail, :tool, or :llm).
  #
  #--
  #: () -> Symbol
  def kind = timing.kind

  # The execution time in seconds.
  #
  #--
  #: () -> Float
  def duration = timing.duration

  # Converts the event to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, timing: timing.to_h}
  end
end
