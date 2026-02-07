# frozen_string_literal: true

# Represents the result of a single evaluation.
#
# Contains the score, reason, and metadata from running an evaluator.
#
#   result = Riffer::Evals::Result.new(
#     evaluator: "answer_relevancy",
#     score: 0.85,
#     reason: "The response addresses the question directly.",
#     higher_is_better: true
#   )
#
#   result.score           # => 0.85
#   result.evaluator       # => "answer_relevancy"
#   result.higher_is_better # => true
#
class Riffer::Evals::Result
  # The identifier of the evaluator that produced this result.
  #
  # Returns String.
  attr_reader :evaluator

  # The evaluation score (0.0 to 1.0).
  #
  # Returns Float.
  attr_reader :score

  # Human-readable explanation of the score.
  #
  # Returns String or nil.
  attr_reader :reason

  # Additional metadata from the evaluation.
  #
  # Returns Hash.
  attr_reader :metadata

  # Whether higher scores are better for this evaluator.
  #
  # Returns Boolean.
  attr_reader :higher_is_better

  # Initializes a new evaluation result.
  #
  # evaluator:: String - the evaluator identifier
  # score:: Float - the score (0.0 to 1.0)
  # reason:: String or nil - optional explanation
  # metadata:: Hash - optional additional data
  # higher_is_better:: Boolean - whether higher is better (default: true)
  #
  # Raises Riffer::ArgumentError if score is not between 0.0 and 1.0.
  def initialize(evaluator:, score:, reason: nil, metadata: {}, higher_is_better: true)
    @evaluator = evaluator
    @score = score.to_f
    validate_score!
    @reason = reason
    @metadata = metadata
    @higher_is_better = higher_is_better
  end

  # Returns a hash representation of the result.
  #
  # Returns Hash.
  def to_h
    {
      evaluator: evaluator,
      score: score,
      reason: reason,
      metadata: metadata,
      higher_is_better: higher_is_better
    }
  end

  private

  def validate_score!
    return if score.is_a?(Numeric) && score >= 0.0 && score <= 1.0

    raise Riffer::ArgumentError, "score must be between 0.0 and 1.0, got #{score}"
  end
end
