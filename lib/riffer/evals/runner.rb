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
#     context: {}
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
  #: (input: String, output: String, ?context: Hash[Symbol, untyped]?) -> Riffer::Evals::RunResult
  def run(input:, output:, context: nil)
    results = metrics.map do |metric|
      evaluator_class = metric.evaluator_class
      raise Riffer::ArgumentError, "Evaluator not found: #{metric.evaluator_identifier}" unless evaluator_class

      evaluator = evaluator_class.new
      evaluator.evaluate(input: input, output: output, context: context)
    end

    Riffer::Evals::RunResult.new(
      input: input,
      output: output,
      context: context,
      results: results,
      metrics: metrics
    )
  end
end
