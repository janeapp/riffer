# frozen_string_literal: true
# rbs_inline: enabled

# Normalized reason the LLM finished, emitted once near the end of the
# stream; no ordering guarantee relative to TokenUsageDone.
class Riffer::StreamEvents::FinishReasonDone < Riffer::StreamEvents::Base
  # The normalized finish reason (see <tt>Riffer::Providers::FinishReason::VALUES</tt>).
  attr_reader :finish_reason #: Symbol

  # The provider's raw finish-reason value, when one exists on the wire.
  attr_reader :raw_finish_reason #: String?

  # Raises Riffer::ArgumentError when +finish_reason+ is outside the
  # normalized vocabulary.
  #--
  #: (finish_reason: Symbol, ?raw_finish_reason: String?, ?role: Symbol) -> void
  def initialize(finish_reason:, raw_finish_reason: nil, role: :assistant)
    unless Riffer::Providers::FinishReason::VALUES.include?(finish_reason)
      raise Riffer::ArgumentError,
            "finish_reason must be one of #{Riffer::Providers::FinishReason::VALUES.inspect}, " \
            "got #{finish_reason.inspect}"
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
