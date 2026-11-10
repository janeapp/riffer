# frozen_string_literal: true

require "test_helper"

class IdentifierTestEvaluator < Riffer::Evals::Evaluator
  judge_model "mock/eval-model"
end

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

  describe ".identifier" do
    it "derives the identifier from the class name" do
      expect(IdentifierTestEvaluator.identifier).must_equal "identifier_test_evaluator"
    end

    it "splits acronyms and namespaces like an agent identifier" do
      klass = Class.new(Riffer::Evals::Evaluator)
      stub_name = "Riffer::Evals::HTTPAccuracyEvaluator"
      klass.define_singleton_method(:name) { stub_name }

      expect(klass.identifier).must_equal "riffer/evals/http_accuracy_evaluator"
    end

    it "returns the set identifier" do
      klass = Class.new(Riffer::Evals::Evaluator) { identifier "accuracy" }

      expect(klass.identifier).must_equal "accuracy"
    end

    it "falls back to the default identifier for anonymous classes" do
      expect(evaluator_class.identifier).must_equal "riffer/judge"
    end
  end

  describe "#evaluate" do
    let(:provider) { register_judge_provider(:evaluator_judge) }

    after { Riffer::Providers::Repository.unregister(:evaluator_judge) }

    def judged_class(instructions_text = "Evaluate quality.")
      Class.new(Riffer::Evals::Evaluator) do
        instructions instructions_text
        judge_model "evaluator_judge/eval-model"
      end
    end

    it "raises NotImplementedError when instructions not set and evaluate not overridden" do
      anon_class = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true
      end

      evaluator = anon_class.new

      expect { evaluator.evaluate(input: "test", output: "test") }.must_raise(NotImplementedError)
    end

    it "calls judge with instructions when instructions are set" do
      provider.stub_response('{"score": 0.8, "reason": "Good"}')

      result = judged_class.new.evaluate(input: "test input", output: "test output")

      expect(result.score).must_equal 0.8
      expect(result.reason).must_equal "Good"
    end

    it "formats array input as labeled messages" do
      provider.stub_response('{"score": 0.8, "reason": "Good"}')

      messages = [
        { role: "user", content: "What is Ruby?" },
        { role: "assistant", content: "Ruby is a programming language." },
        { "role" => "user", "content" => "Tell me more." },
      ]

      judged_class.new.evaluate(input: messages, output: "test output")
      prompt = provider.calls.last[:messages].last[:content]
      formatted = "user: What is Ruby?\n\nassistant: Ruby is a programming language.\n\nuser: Tell me more."

      expect(prompt).must_include formatted
    end

    it "passes ground_truth to judge" do
      provider.stub_response('{"score": 0.95, "reason": "Matches"}')

      result = judged_class("Compare to ground truth.").new.
        evaluate(input: "question", output: "answer", ground_truth: "expected")

      expect(result.score).must_equal 0.95
      expect(provider.calls.last[:messages].last[:content]).must_include "## Ground Truth\n\nexpected"
    end

    it "captures the judge's token usage on the result" do
      provider.stub_response(
        '{"score": 0.8, "reason": "Good"}',
        token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 30, output_tokens: 12),
      )

      result = judged_class.new.evaluate(input: "test input", output: "test output")

      expect(result.token_usage.total_tokens).must_equal 42
    end

    it "falls back to Riffer::Evals.config.judge_model" do
      provider.stub_response('{"score": 0.7, "reason": "Fine"}')
      klass = Class.new(Riffer::Evals::Evaluator) { instructions "Evaluate quality." }
      Riffer::Evals.config.judge_model = "evaluator_judge/eval-model"

      expect(klass.new.evaluate(input: "test", output: "test").score).must_equal 0.7
    ensure
      Riffer::Evals.config.judge_model = nil
    end

    it "raises when no judge model is configured" do
      klass = Class.new(Riffer::Evals::Evaluator) { instructions "Evaluate quality." }
      error = expect { klass.new.evaluate(input: "test", output: "test") }.must_raise Riffer::ArgumentError

      expect(error.message).must_include "Riffer::Evals.config.judge_model"
    end
  end

  describe "#judge (protected)" do
    it "builds a judge for the evaluator's model and identifier" do
      judge = IdentifierTestEvaluator.new.send(:judge)

      expect([judge.model, judge.identifier]).must_equal ["mock/eval-model", "identifier_test_evaluator"]
    end
  end

  describe "#result (protected)" do
    it "creates a Result with correct attributes" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true

        def evaluate(input:, output:, ground_truth: nil, messages: [])
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

        def evaluate(input:, output:, ground_truth: nil, messages: [])
          result(score: 0.1, reason: "Low toxicity")
        end
      end

      evaluator = klass.new
      result = evaluator.evaluate(input: "test", output: "test")

      expect(result.higher_is_better).must_equal false
    end
  end
end
