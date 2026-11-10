# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::RunResult
  attr_reader :scenario_results #: Array[Riffer::Evals::ScenarioResult] # @dynamic scenario_results

  #--
  #: (scenario_results: Array[Riffer::Evals::ScenarioResult]) -> void
  def initialize(scenario_results:)
    @scenario_results = scenario_results
  end

  #--
  #: () -> Hash[singleton(Riffer::Evals::Evaluator), Float]
  def scores
    pairs = scenario_results.flat_map { |scenario| scenario.scores.to_a }
    pairs.group_by(&:first).transform_values { |scored| scored.sum(&:last) / scored.size }
  end

  #--
  #: () -> Riffer::Providers::TokenUsage?
  def token_usage
    scenario_results.filter_map(&:token_usage).reduce(:+)
  end

  #--
  #: () -> Riffer::Providers::TokenUsage?
  def evaluator_token_usage
    scenario_results.filter_map(&:evaluator_token_usage).reduce(:+)
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      scores: scores.transform_keys(&:name),
      scenario_results: scenario_results.map(&:to_h),
      token_usage: token_usage&.to_h,
      evaluator_token_usage: evaluator_token_usage&.to_h,
    }
  end
end
