# frozen_string_literal: true
# rbs_inline: enabled

# Orchestrates running multiple evaluators against agent output.
#
# The Runner takes a set of metrics and runs each evaluator,
# collecting results into a RunResult.
#
#   runner = Riffer::Evals::Runner.new(metrics: [metric1, metric2])
#   run_result = runner.run(
#     input: "What is the capital of France?",
#     output: "The capital of France is Paris.",
#     ground_truth: "Paris"
#   )
#
class Riffer::Evals::Runner
  # The metrics to evaluate.
  attr_reader :metrics #: Array[Riffer::Evals::Metric]

  # Initializes a new runner.
  #
  #: (metrics: Array[Riffer::Evals::Metric]) -> void
  def initialize(metrics:)
    @metrics = metrics
  end

  # Runs all evaluators and collects results.
  #
  #: (input: String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base], output: String, ?ground_truth: String?) -> Riffer::Evals::RunResult
  def run(input:, output:, ground_truth: nil)
    results = metrics.map do |metric|
      evaluator = metric.evaluator_class.new
      evaluator.evaluate(input: input, output: output, ground_truth: ground_truth)
    end

    Riffer::Evals::RunResult.new(
      input: input,
      output: output,
      ground_truth: ground_truth,
      results: results,
      metrics: metrics
    )
  end
end
