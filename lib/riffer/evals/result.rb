# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::Result
  attr_reader :evaluator #: singleton(Riffer::Evals::Evaluator)

  attr_reader :score #: Float

  attr_reader :reason #: String?

  attr_reader :metadata #: Hash[Symbol, untyped]

  attr_reader :higher_is_better #: bool

  #: (evaluator: singleton(Riffer::Evals::Evaluator), score: Float, ?reason: String?, ?metadata: Hash[Symbol, untyped], ?higher_is_better: bool) -> void
  def initialize(evaluator:, score:, reason: nil, metadata: {}, higher_is_better: true)
    @evaluator = evaluator
    @score = score.to_f
    validate_score!
    @reason = reason
    @metadata = metadata
    @higher_is_better = higher_is_better
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      evaluator: evaluator.name,
      score: score,
      reason: reason,
      metadata: metadata,
      higher_is_better: higher_is_better
    }
  end

  private

  #: () -> void
  def validate_score!
    return if score.is_a?(Numeric) && score >= 0.0 && score <= 1.0

    raise Riffer::ArgumentError, "score must be between 0.0 and 1.0, got #{score}"
  end
end
