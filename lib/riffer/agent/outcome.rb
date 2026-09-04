# frozen_string_literal: true
# rbs_inline: enabled

# How a run ended — the single place to read whether the agent completed
# normally and, if not, why. +detail+ carries the specifics when there are any:
# the tripwire reason, the interrupt reason, the provider's raw finish value,
# or the structured output parse/validation error.
#
#   response = agent.generate("Analyze this")
#   case response.outcome.reason
#   when :completed then puts response.structured_output
#   when :invalid_structured_output then warn response.outcome.detail
#   end
class Riffer::Agent::Outcome
  # Finish reasons that mean the provider cut the turn short; they surface as
  # the run's outcome verbatim.
  PROVIDER_STOP_REASONS = %i[length content_filter context_window malformed_output error other].freeze #: Array[Symbol]

  # The vocabulary every run ends in.
  VALUES = (%i[completed guardrail_blocked interrupted max_steps invalid_structured_output] +
            PROVIDER_STOP_REASONS).freeze #: Array[Symbol]

  # Why the run ended.
  attr_reader :reason #: Symbol

  # Human-readable specifics for +reason+, when there are any.
  attr_reader :detail #: String?

  # Raises Riffer::ArgumentError when +reason+ is outside VALUES.
  #--
  #: (reason: Symbol, ?detail: String?) -> void
  def initialize(reason:, detail: nil)
    unless VALUES.include?(reason)
      raise Riffer::ArgumentError, "reason must be one of #{VALUES.inspect}, got #{reason.inspect}"
    end

    @reason = reason
    @detail = detail
  end

  # Returns true when the run completed normally.
  #
  #--
  #: () -> bool
  def success?
    reason == :completed
  end
end
