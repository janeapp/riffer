# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::ScenarioResult do
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

  let(:result_a) do
    Riffer::Evals::Result.new(evaluator: evaluator_class, score: 0.9, reason: "Good")
  end

  let(:result_b) do
    Riffer::Evals::Result.new(evaluator: other_evaluator_class, score: 0.7, reason: "Okay")
  end

  describe "#initialize" do
    it "sets all attributes" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "What is Ruby?",
        output: "A programming language.",
        ground_truth: "A programming language",
        results: [result_a]
      )

      expect(scenario.input).must_equal "What is Ruby?"
      expect(scenario.output).must_equal "A programming language."
      expect(scenario.ground_truth).must_equal "A programming language"
      expect(scenario.results).must_equal [result_a]
    end
  end

  describe "#scores" do
    it "returns scores keyed by evaluator class" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [result_a, result_b]
      )

      expect(scenario.scores[evaluator_class]).must_equal 0.9
      expect(scenario.scores[other_evaluator_class]).must_equal 0.7
    end

    it "returns empty hash when no results" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: []
      )

      expect(scenario.scores).must_be_empty
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "What is Ruby?",
        output: "A language.",
        ground_truth: "A programming language",
        results: [result_a]
      )

      hash = scenario.to_h
      expect(hash[:input]).must_equal "What is Ruby?"
      expect(hash[:output]).must_equal "A language."
      expect(hash[:ground_truth]).must_equal "A programming language"
      expect(hash[:results].length).must_equal 1
      expect(hash[:scores]).must_be_instance_of Hash
    end
  end
end
