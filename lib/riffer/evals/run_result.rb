# frozen_string_literal: true
# rbs_inline: enabled

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
  #: @failures: Array[Riffer::Evals::Result]?

  # The input that was evaluated.
  attr_reader :input #: String

  # The output that was evaluated.
  attr_reader :output #: String

  # The context used during evaluation.
  attr_reader :context #: Hash[Symbol, untyped]?

  # Individual evaluation results.
  attr_reader :results #: Array[Riffer::Evals::Result]

  # The metrics that were evaluated.
  attr_reader :metrics #: Array[Riffer::Evals::Metric]

  # Initializes a new run result.
  #
  #: input: String -- the input that was evaluated
  #: output: String -- the output that was evaluated
  #: context: Hash[Symbol, untyped]? -- the evaluation context
  #: results: Array[Riffer::Evals::Result] -- individual results
  #: metrics: Array[Riffer::Evals::Metric] -- the metrics evaluated
  #: return: void
  def initialize(input:, output:, context:, results:, metrics:)
    @input = input
    @output = output
    @context = context
    @results = results
    @metrics = metrics
  end

  # Checks if all metrics passed their thresholds.
  #
  #: return: bool
  def passed?
    failures.empty?
  end

  # Returns results that failed their metric thresholds.
  #
  #: return: Array[Riffer::Evals::Result]
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
  #: return: Float
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
  #: return: Hash[Symbol, untyped]
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
