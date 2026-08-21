# frozen_string_literal: true
# rbs_inline: enabled

# Represents the result of a single evaluation.
class Riffer::Evals::Result
  # The evaluator class that produced this result.
  attr_reader :evaluator #: singleton(Riffer::Evals::Evaluator)

  # The evaluation score (0.0 to 1.0).
  attr_reader :score #: Float

  # Human-readable explanation of the score.
  attr_reader :reason #: String?

  # Additional metadata from the evaluation.
  attr_reader :metadata #: Hash[Symbol, untyped]

  # Whether higher scores are better for this evaluator.
  attr_reader :higher_is_better #: bool

  # Token usage for the judge call that produced this result, when the
  # evaluator used an LLM. Nil for rule-based evaluators.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  # Raises Riffer::ArgumentError if +score+ is not between 0.0 and 1.0.
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

  # Returns a hash representation of the result.
  #
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
