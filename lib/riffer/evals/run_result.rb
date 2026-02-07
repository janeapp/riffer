# frozen_string_literal: true

# Represents the complete result of an evaluation run.
#
# Contains all individual results and provides aggregate metrics.
#
#   run_result = Riffer::Evals::RunResult.new(
#     input: "question",
#     output: "answer",
#     context: {},
#     results: [result1, result2],
#     metrics: [metric1, metric2]
#   )
#
#   run_result.passed?          # => true/false
#   run_result.aggregate_score  # => 0.87
#   run_result.failures         # => [result1] (results that failed thresholds)
#
class Riffer::Evals::RunResult
  # The input that was evaluated.
  #
  # Returns String.
  attr_reader :input

  # The output that was evaluated.
  #
  # Returns String.
  attr_reader :output

  # The context used during evaluation.
  #
  # Returns Hash or nil.
  attr_reader :context

  # Individual evaluation results.
  #
  # Returns Array of Riffer::Evals::Result.
  attr_reader :results

  # The metrics that were evaluated.
  #
  # Returns Array of Riffer::Evals::Metric.
  attr_reader :metrics

  # Initializes a new run result.
  #
  # input:: String - the input that was evaluated
  # output:: String - the output that was evaluated
  # context:: Hash or nil - the evaluation context
  # results:: Array of Riffer::Evals::Result - individual results
  # metrics:: Array of Riffer::Evals::Metric - the metrics evaluated
  def initialize(input:, output:, context:, results:, metrics:)
    @input = input
    @output = output
    @context = context
    @results = results
    @metrics = metrics
  end

  # Checks if all metrics passed their thresholds.
  #
  # Returns Boolean.
  def passed?
    failures.empty?
  end

  # Returns results that failed their metric thresholds.
  #
  # Returns Array of Riffer::Evals::Result.
  def failures
    @failures ||= results.select.with_index do |result, index|
      metric = metrics[index]
      !metric.passes?(result)
    end
  end

  # Calculates the weighted aggregate score.
  #
  # Scores are normalized so that higher is always better for aggregation.
  # For evaluators where lower is better (e.g., toxicity), the score is
  # inverted (1 - score) before aggregation.
  #
  # Returns Float.
  def aggregate_score
    return 0.0 if results.empty?

    total_weight = metrics.sum(&:weight)
    return 0.0 if total_weight.zero?

    weighted_sum = results.zip(metrics).sum do |result, metric|
      # Normalize score: for higher_is_better=false, invert so higher is better
      normalized_score = result.higher_is_better ? result.score : (1.0 - result.score)
      normalized_score * metric.weight
    end

    weighted_sum / total_weight
  end

  # Returns a hash representation of the run result.
  #
  # Returns Hash.
  def to_h
    {
      input: input,
      output: output,
      context: context,
      results: results.map(&:to_h),
      passed: passed?,
      aggregate_score: aggregate_score
    }
  end
end
