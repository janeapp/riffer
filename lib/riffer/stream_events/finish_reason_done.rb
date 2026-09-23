# frozen_string_literal: true
# rbs_inline: enabled

# No ordering guarantee relative to TokenUsageDone.
class Riffer::StreamEvents::FinishReasonDone < Riffer::StreamEvents::Base
  attr_reader :finish_reason #: Symbol # @dynamic finish_reason

  attr_reader :raw_finish_reason #: String? # @dynamic raw_finish_reason

  #--
  #: (finish_reason: Symbol, ?raw_finish_reason: String?, ?role: Symbol) -> void
  def initialize(finish_reason:, raw_finish_reason: nil, role: :assistant)
    unless Riffer::Providers::FinishReason::VALUES.include?(finish_reason)
      values = Riffer::Providers::FinishReason::VALUES.inspect
      raise Riffer::ArgumentError, "finish_reason must be one of #{values}, got #{finish_reason.inspect}"
    end

    super(role: role)
    @finish_reason = finish_reason
    @raw_finish_reason = raw_finish_reason
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: @role, finish_reason: @finish_reason } #: Hash[Symbol, untyped]
    hash[:raw_finish_reason] = @raw_finish_reason if @raw_finish_reason
    hash
  end
end
