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
  #--
  # @dynamic reason, detail

  # Finish reasons that end a turn normally; every other finish reason means the
  # provider cut the turn short and surfaces as the run's outcome verbatim.
  NORMAL_FINISH_REASONS = %i[stop tool_calls].freeze #: Array[Symbol]

  # Derived from the provider vocabulary so a new finish reason becomes an
  # outcome without a second list to update.
  PROVIDER_STOP_REASONS = (Riffer::Providers::FinishReason::VALUES - NORMAL_FINISH_REASONS).freeze #: Array[Symbol]

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
