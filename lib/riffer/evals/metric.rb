# frozen_string_literal: true

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
  #
  # Returns String.
  attr_reader :evaluator_identifier

  # Minimum acceptable score (for higher_is_better evaluators).
  #
  # Returns Float or nil.
  attr_reader :min

  # Maximum acceptable score (for lower_is_better evaluators).
  #
  # Returns Float or nil.
  attr_reader :max

  # Weight for aggregate scoring (default: 1.0).
  #
  # Returns Float.
  attr_reader :weight

  # Initializes a new metric.
  #
  # evaluator_identifier:: String - the evaluator to use
  # min:: Float or nil - minimum score threshold
  # max:: Float or nil - maximum score threshold
  # weight:: Float - weight for aggregation (default: 1.0)
  def initialize(evaluator_identifier:, min: nil, max: nil, weight: 1.0)
    @evaluator_identifier = evaluator_identifier.to_s
    @min = min&.to_f
    @max = max&.to_f
    @weight = weight.to_f
  end

  # Returns the evaluator class for this metric.
  #
  # Returns Class or nil.
  def evaluator_class
    Riffer::Evals::Evaluators::Repository.find(evaluator_identifier)
  end

  # Checks if a result passes this metric's thresholds.
  #
  # result:: Riffer::Evals::Result - the evaluation result to check
  #
  # Returns Boolean.
  def passes?(result)
    return false if min && result.score < min
    return false if max && result.score > max
    true
  end

  # Returns a hash representation of the metric.
  #
  # Returns Hash.
  def to_h
    {
      evaluator_identifier: evaluator_identifier,
      min: min,
      max: max,
      weight: weight
    }
  end
end
