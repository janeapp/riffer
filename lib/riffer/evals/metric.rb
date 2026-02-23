# frozen_string_literal: true
# rbs_inline: enabled

# Represents a metric configuration with thresholds.
#
# Metrics define which evaluator to use and what thresholds determine pass/fail.
#
#   metric = Riffer::Evals::Metric.new(
#     evaluator_class: AnswerRelevancyEvaluator,
#     min: 0.85,
#     weight: 1.0
#   )
#
#   metric.passes?(result)  # => true/false based on thresholds
#
class Riffer::Evals::Metric
  # The evaluator class to use.
  attr_reader :evaluator_class #: singleton(Riffer::Evals::Evaluator)

  # Minimum acceptable score (for higher_is_better evaluators).
  attr_reader :min #: Float?

  # Maximum acceptable score (for lower_is_better evaluators).
  attr_reader :max #: Float?

  # Weight for aggregate scoring (default: 1.0).
  attr_reader :weight #: Float

  # Initializes a new metric.
  #
  # Raises Riffer::ArgumentError if evaluator_class is not a subclass of Riffer::Evals::Evaluator.
  #
  #: (evaluator_class: singleton(Riffer::Evals::Evaluator), ?min: Float?, ?max: Float?, ?weight: Float) -> void
  def initialize(evaluator_class:, min: nil, max: nil, weight: 1.0)
    unless evaluator_class.is_a?(Class) && evaluator_class < Riffer::Evals::Evaluator
      raise Riffer::ArgumentError, "evaluator_class must be a subclass of Riffer::Evals::Evaluator, got #{evaluator_class.inspect}"
    end

    @evaluator_class = evaluator_class
    @min = min&.to_f
    @max = max&.to_f
    @weight = weight.to_f
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
      evaluator_class: evaluator_class,
      min: min,
      max: max,
      weight: weight
    }
  end
end
