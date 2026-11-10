# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::Result
  attr_reader :evaluator #: singleton(Riffer::Evals::Evaluator) # @dynamic evaluator

  attr_reader :score #: Float # @dynamic score

  attr_reader :reason #: String? # @dynamic reason

  attr_reader :metadata #: Hash[Symbol, untyped] # @dynamic metadata

  attr_reader :higher_is_better #: bool # @dynamic higher_is_better

  # Nil for rule-based evaluators.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage

  #--
  #: (evaluator: singleton(Riffer::Evals::Evaluator), score: Float, ?reason: String?, ?metadata: Hash[Symbol, untyped], ?higher_is_better: bool, ?token_usage: Riffer::Providers::TokenUsage?) -> void
  def initialize(evaluator:, score:, reason: nil, metadata: {}, higher_is_better: true, token_usage: nil)
    @evaluator = evaluator
    @score = score.to_f
    validate_score!
    @reason = reason
    @metadata = metadata
    @higher_is_better = higher_is_better
    @token_usage = token_usage
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      evaluator: evaluator.name,
      score: score,
      reason: reason,
      metadata: metadata,
      higher_is_better: higher_is_better,
      token_usage: token_usage&.to_h,
    }
  end

  private

  #--
  #: () -> void
  def validate_score!
    return if score.is_a?(Numeric) && score >= 0.0 && score <= 1.0

    raise Riffer::ArgumentError, "score must be between 0.0 and 1.0, got #{score}"
  end
end
