# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::RunResult do
  let(:evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true
    end
  end

  let(:other_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true
    end
  end

  let(:scenario_a) do
    Riffer::Evals::ScenarioResult.new(
      input: "What is Ruby?",
      output: "A programming language.",
      ground_truth: nil,
      results: [
        Riffer::Evals::Result.new(evaluator: evaluator_class, score: 0.9),
        Riffer::Evals::Result.new(evaluator: other_evaluator_class, score: 0.8)
      ]
    )
  end

  let(:scenario_b) do
    Riffer::Evals::ScenarioResult.new(
      input: "What is Python?",
      output: "A snake.",
      ground_truth: nil,
      results: [
        Riffer::Evals::Result.new(evaluator: evaluator_class, score: 0.3),
        Riffer::Evals::Result.new(evaluator: other_evaluator_class, score: 0.6)
      ]
    )
  end

  describe "#initialize" do
    it "sets scenario_results" do
      run_result = Riffer::Evals::RunResult.new(scenario_results: [scenario_a])

      expect(run_result.scenario_results).must_equal [scenario_a]
    end
  end

  describe "#scores" do
    it "returns average scores across scenarios" do
      run_result = Riffer::Evals::RunResult.new(scenario_results: [scenario_a, scenario_b])

      expect(run_result.scores[evaluator_class]).must_be_close_to 0.6, 0.0001
      expect(run_result.scores[other_evaluator_class]).must_be_close_to 0.7, 0.0001
    end

    it "returns scores for single scenario" do
      run_result = Riffer::Evals::RunResult.new(scenario_results: [scenario_a])

      expect(run_result.scores[evaluator_class]).must_equal 0.9
      expect(run_result.scores[other_evaluator_class]).must_equal 0.8
    end

    it "returns empty hash when no scenarios" do
      run_result = Riffer::Evals::RunResult.new(scenario_results: [])

      expect(run_result.scores).must_be_empty
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      run_result = Riffer::Evals::RunResult.new(scenario_results: [scenario_a])

      hash = run_result.to_h
      expect(hash[:scores]).must_be_instance_of Hash
      expect(hash[:scenario_results].length).must_equal 1
    end
  end
end
