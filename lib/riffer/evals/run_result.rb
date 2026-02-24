# frozen_string_literal: true
# rbs_inline: enabled

# Represents the complete result of an evaluation run across multiple scenarios.
#
# Contains per-scenario results and provides aggregate scores.
#
#   run_result = Riffer::Evals::RunResult.new(
#     scenario_results: [scenario_result1, scenario_result2]
#   )
#
#   run_result.scores   # => { MyEvaluator => 0.85 }
#
class Riffer::Evals::RunResult
  # Per-scenario evaluation results.
  attr_reader :scenario_results #: Array[Riffer::Evals::ScenarioResult]

  # Initializes a new run result.
  #
  #: (scenario_results: Array[Riffer::Evals::ScenarioResult]) -> void
  def initialize(scenario_results:)
    @scenario_results = scenario_results
  end

  # Returns average scores keyed by evaluator class across all scenarios.
  #
  #: () -> Hash[singleton(Riffer::Evals::Evaluator), Float]
  def scores
    return {} if scenario_results.empty?

    totals = Hash.new(0.0)
    counts = Hash.new(0)

    scenario_results.each do |scenario|
      scenario.scores.each do |evaluator, score|
        totals[evaluator] += score
        counts[evaluator] += 1
      end
    end

    totals.each_with_object({}) do |(evaluator, total), hash|
      hash[evaluator] = total / counts[evaluator]
    end
  end

  # Returns a hash representation of the run result.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      scores: scores.transform_keys(&:name),
      scenario_results: scenario_results.map(&:to_h)
    }
  end
end
