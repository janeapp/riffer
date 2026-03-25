# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Evals::RunResult
  attr_reader :scenario_results #: Array[Riffer::Evals::ScenarioResult]

  #: (scenario_results: Array[Riffer::Evals::ScenarioResult]) -> void
  def initialize(scenario_results:)
    @scenario_results = scenario_results
  end

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

  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      scores: scores.transform_keys(&:name),
      scenario_results: scenario_results.map(&:to_h)
    }
  end
end
