# frozen_string_literal: true
# rbs_inline: enabled

# Represents the complete result of an evaluation run across multiple scenarios.
class Riffer::Evals::RunResult
  # Per-scenario evaluation results.
  attr_reader :scenario_results #: Array[Riffer::Evals::ScenarioResult]

  #--
  #: (scenario_results: Array[Riffer::Evals::ScenarioResult]) -> void
  def initialize(scenario_results:)
    @scenario_results = scenario_results
  end

  # Returns average scores keyed by evaluator class across all scenarios.
  #
  #--
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

    averages = {} #: Hash[singleton(Riffer::Evals::Evaluator), Float]
    totals.each_with_object(averages) do |(evaluator, total), hash|
      hash[evaluator] = total / counts[evaluator]
    end
  end

  # Returns the summed token usage the agents under test spent across every
  # scenario, or nil when none reported usage.
  #
  #--
  #: () -> Riffer::Providers::TokenUsage?
  def token_usage
    scenario_results.map(&:token_usage).compact.reduce(:+)
  end

  # Returns the summed token usage across every scenario's LLM-as-judge
  # evaluators, or nil when none reported usage.
  #
  #--
  #: () -> Riffer::Providers::TokenUsage?
  def evaluator_token_usage
    scenario_results.map(&:evaluator_token_usage).compact.reduce(:+)
  end

  # Returns a hash representation of the run result.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      scores: scores.transform_keys(&:name),
      scenario_results: scenario_results.map(&:to_h),
      token_usage: token_usage&.to_h,
      evaluator_token_usage: evaluator_token_usage&.to_h
    }
  end
end
