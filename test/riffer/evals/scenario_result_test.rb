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
        results: [result_a],
      )

      expect(scenario.input).must_equal "What is Ruby?"
      expect(scenario.output).must_equal "A programming language."
      expect(scenario.ground_truth).must_equal "A programming language"
      expect(scenario.results).must_equal [result_a]
    end
  end

  describe "#messages" do
    it "defaults to empty array" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [],
      )

      expect(scenario.messages).must_equal []
    end

    it "stores provided messages" do
      messages = [Riffer::Messages::User.new("Hi"), Riffer::Messages::Assistant.new("Hello")]
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [],
        messages: messages,
      )

      expect(scenario.messages).must_equal messages
    end
  end

  describe "#scores" do
    it "returns scores keyed by evaluator class" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [result_a, result_b],
      )

      expect(scenario.scores[evaluator_class]).must_equal 0.9
      expect(scenario.scores[other_evaluator_class]).must_equal 0.7
    end

    it "returns empty hash when no results" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [],
      )

      expect(scenario.scores).must_be_empty
    end
  end

  describe "#evaluator_token_usage" do
    it "sums token usage across results" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [
          Riffer::Evals::Result.new(evaluator: evaluator_class, score: 0.9,
                                    token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 10, output_tokens: 5),),
          Riffer::Evals::Result.new(evaluator: other_evaluator_class, score: 0.7,
                                    token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 20, output_tokens: 8),),
        ],
      )

      expect(scenario.evaluator_token_usage.total_tokens).must_equal 43
    end

    it "returns nil when no result reports token usage" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [result_a, result_b],
      )

      expect(scenario.evaluator_token_usage).must_be_nil
    end
  end

  describe "#token_usage" do
    it "returns the agent usage it was constructed with" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 30, output_tokens: 12)
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [],
        token_usage: usage,
      )

      expect(scenario.token_usage).must_equal usage
    end

    it "defaults to nil" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "test",
        output: "test",
        ground_truth: nil,
        results: [],
      )

      expect(scenario.token_usage).must_be_nil
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      scenario = Riffer::Evals::ScenarioResult.new(
        input: "What is Ruby?",
        output: "A language.",
        ground_truth: "A programming language",
        results: [result_a],
      )

      hash = scenario.to_h

      expect(hash[:input]).must_equal "What is Ruby?"
      expect(hash[:output]).must_equal "A language."
      expect(hash[:ground_truth]).must_equal "A programming language"
      expect(hash[:results].length).must_equal 1
      expect(hash[:scores]).must_be_instance_of Hash
      expect(hash[:messages]).must_be_instance_of Array
    end
  end
end
