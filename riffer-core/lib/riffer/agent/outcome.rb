# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::Outcome
  NORMAL_FINISH_REASONS = %i[stop tool_calls].freeze #: Array[Symbol]

  PROVIDER_STOP_REASONS = (Riffer::Providers::FinishReason::VALUES - NORMAL_FINISH_REASONS).freeze #: Array[Symbol]

  VALUES = (%i[completed guardrail_blocked interrupted max_steps invalid_structured_output] +
            PROVIDER_STOP_REASONS).freeze #: Array[Symbol]

  attr_reader :reason #: Symbol # @dynamic reason

  attr_reader :detail #: String? # @dynamic detail

  #--
  #: (reason: Symbol, ?detail: String?) -> void
  def initialize(reason:, detail: nil)
    unless VALUES.include?(reason)
      raise Riffer::ArgumentError, "reason must be one of #{VALUES.inspect}, got #{reason.inspect}"
    end

    @reason = reason
    @detail = detail
  end

  #--
  #: () -> bool
  def success?
    reason == :completed
  end
end
