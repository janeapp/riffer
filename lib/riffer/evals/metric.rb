# frozen_string_literal: true
# rbs_inline: enabled

# Represents a metric configuration with thresholds.
#
# Metrics define which evaluator to use and what thresholds determine pass/fail.
#
#   metric = Riffer::Evals::Metric.new(
#     evaluator_identifier: "answer_relevancy",
#     min: 0.85,
#     weight: 1.0
#   )
#
#   metric.passes?(result)  # => true/false based on thresholds
#
class Riffer::Evals::Metric
  # The identifier of the evaluator to use.
  attr_reader :evaluator_identifier #: String

  # Minimum acceptable score (for higher_is_better evaluators).
  attr_reader :min #: Float?

  # Maximum acceptable score (for lower_is_better evaluators).
  attr_reader :max #: Float?

  # Weight for aggregate scoring (default: 1.0).
  attr_reader :weight #: Float

  # Initializes a new metric.
  #
  #: (evaluator_identifier: String, ?min: Float?, ?max: Float?, ?weight: Float) -> void
  def initialize(evaluator_identifier:, min: nil, max: nil, weight: 1.0)
    @evaluator_identifier = evaluator_identifier.to_s
    @min = min&.to_f
    @max = max&.to_f
    @weight = weight.to_f
  end

  # Returns the evaluator class for this metric.
  #
  #: () -> singleton(Riffer::Evals::Evaluator)?
  def evaluator_class
    Riffer::Evals::Evaluators::Repository.find(evaluator_identifier)
  end

  # Checks if a result passes this metric's thresholds.
  #
  #: (Riffer::Evals::Result) -> bool
  def passes?(result)
    return false if min && result.score < min
    return false if max && result.score > max
    true
  end

  # Returns a hash representation of the metric.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      evaluator_identifier: evaluator_identifier,
      min: min,
      max: max,
      weight: weight
    }
  end
end
