# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::FinishReason
  VALUES = %i[stop length tool_calls content_filter context_window malformed_output error other].freeze #: Array[Symbol]

  attr_reader :reason #: Symbol # @dynamic reason

  attr_reader :raw #: String? # @dynamic raw

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
