# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Evaluator do
  let(:evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      instructions "Test evaluation instructions"
      higher_is_better true
    end
  end

  let(:lower_is_better_class) do
    Class.new(Riffer::Evals::Evaluator) do
      instructions "Detects toxicity"
      higher_is_better false
    end
  end

  describe ".instructions" do
    it "returns the set instructions" do
      expect(evaluator_class.instructions).must_equal "Test evaluation instructions"
    end

    it "returns nil when not set" do
      anon_class = Class.new(Riffer::Evals::Evaluator)
      expect(anon_class.instructions).must_be_nil
    end
  end

  describe ".higher_is_better" do
    it "returns true when set to true" do
      expect(evaluator_class.higher_is_better).must_equal true
    end

    it "returns false when set to false" do
      expect(lower_is_better_class.higher_is_better).must_equal false
    end

    it "defaults to true when not set" do
      anon_class = Class.new(Riffer::Evals::Evaluator)
      expect(anon_class.higher_is_better).must_equal true
    end
  end

  describe ".judge_model" do
    it "returns the set judge model" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        judge_model "anthropic/claude-sonnet-4-20250514"
      end
      expect(klass.judge_model).must_equal "anthropic/claude-sonnet-4-20250514"
    end

    it "returns nil when not set" do
      expect(evaluator_class.judge_model).must_be_nil
    end
  end

  describe "#evaluate" do
    it "raises NotImplementedError when instructions not set and evaluate not overridden" do
      anon_class = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true
      end

      evaluator = anon_class.new
      expect { evaluator.evaluate(input: "test", output: "test") }.must_raise(NotImplementedError)
    end

    it "calls judge with instructions when instructions are set" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        instructions "Evaluate quality."
        judge_model "mock/eval-model"
      end

      evaluator = klass.new
      judge = evaluator.send(:judge)
      provider = judge.send(:provider_instance)
      provider.stub_response("", tool_calls: [{name: "evaluation", arguments: {score: 0.8, reason: "Good"}}])

      result = evaluator.evaluate(input: "test input", output: "test output")

      expect(result.score).must_equal 0.8
      expect(result.reason).must_equal "Good"
    end

    it "formats array input as labeled messages" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        instructions "Evaluate quality."
        judge_model "mock/eval-model"
      end

      evaluator = klass.new
      judge = evaluator.send(:judge)
      provider = judge.send(:provider_instance)
      provider.stub_response("", tool_calls: [{name: "evaluation", arguments: {score: 0.8, reason: "Good"}}])

      messages = [
        {role: "user", content: "What is Ruby?"},
        {role: "assistant", content: "Ruby is a programming language."},
        {role: "user", content: "Tell me more."}
      ]

      result = evaluator.evaluate(input: messages, output: "test output")

      expect(result.score).must_equal 0.8
    end

    it "passes ground_truth to judge" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        instructions "Compare to ground truth."
        judge_model "mock/eval-model"
      end

      evaluator = klass.new
      judge = evaluator.send(:judge)
      provider = judge.send(:provider_instance)
      provider.stub_response("", tool_calls: [{name: "evaluation", arguments: {score: 0.95, reason: "Matches"}}])

      result = evaluator.evaluate(input: "question", output: "answer", ground_truth: "expected")

      expect(result.score).must_equal 0.95
    end
  end

  describe "#result (protected)" do
    it "creates a Result with correct attributes" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true

        def evaluate(input:, output:, ground_truth: nil)
          result(score: 0.9, reason: "Good")
        end
      end

      evaluator = klass.new
      result = evaluator.evaluate(input: "test", output: "test")

      expect(result.evaluator).must_equal klass
      expect(result.score).must_equal 0.9
      expect(result.reason).must_equal "Good"
      expect(result.metadata).must_equal({})
      expect(result.higher_is_better).must_equal true
    end

    it "creates a Result with higher_is_better from evaluator" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better false

        def evaluate(input:, output:, ground_truth: nil)
          result(score: 0.1, reason: "Low toxicity")
        end
      end

      evaluator = klass.new
      result = evaluator.evaluate(input: "test", output: "test")

      expect(result.higher_is_better).must_equal false
    end
  end
end
