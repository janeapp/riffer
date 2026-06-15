# frozen_string_literal: true
# rbs_inline: enabled

# Normalized reason an LLM call finished, paired with the provider's raw
# wire value. +reason+ carries the same meaning for every provider.
class Riffer::Providers::FinishReason
  # The normalized vocabulary every provider maps into.
  VALUES = %i[stop length tool_calls content_filter error other].freeze #: Array[Symbol]

  # The normalized reason.
  attr_reader :reason #: Symbol

  # The provider's raw finish-reason value, when one exists on the wire.
  attr_reader :raw #: String?

  # Raises Riffer::ArgumentError when +reason+ is outside VALUES.
  #--
  #: (reason: Symbol, ?raw: String?) -> void
  def initialize(reason:, raw: nil)
    unless VALUES.include?(reason)
      raise Riffer::ArgumentError, "reason must be one of #{VALUES.inspect}, got #{reason.inspect}"
    end

    @reason = reason
    @raw = raw
  end
end
