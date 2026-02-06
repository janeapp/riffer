# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Evaluator do
  let(:evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      identifier "test_evaluator"
      description "A test evaluator"
      higher_is_better true
    end
  end

  let(:lower_is_better_class) do
    Class.new(Riffer::Evals::Evaluator) do
      identifier "toxicity"
      description "Detects toxicity"
      higher_is_better false
    end
  end

  describe ".identifier" do
    it "returns the set identifier" do
      expect(evaluator_class.identifier).must_equal "test_evaluator"
    end

    it "generates identifier from class name when not set" do
      anon_class = Class.new(Riffer::Evals::Evaluator)
      # Anonymous classes don't have a name, so this returns nil
      expect(anon_class.identifier).must_be_nil
    end

    it "strips _evaluator suffix from generated identifier" do
      # Create a named class to test
      eval <<~RUBY, binding, __FILE__, __LINE__ + 1
        class TestNamedEvaluator < Riffer::Evals::Evaluator
        end
      RUBY

      expect(TestNamedEvaluator.identifier).must_equal "test_named"

      Object.send(:remove_const, :TestNamedEvaluator)
    end
  end

  describe ".description" do
    it "returns the set description" do
      expect(evaluator_class.description).must_equal "A test evaluator"
    end

    it "returns nil when not set" do
      anon_class = Class.new(Riffer::Evals::Evaluator)
      expect(anon_class.description).must_be_nil
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
    it "raises NotImplementedError when not implemented" do
      evaluator = evaluator_class.new
      expect { evaluator.evaluate(input: "test", output: "test") }.must_raise(NotImplementedError)
    end
  end

  describe "#result (protected)" do
    it "creates a Result with correct attributes" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        identifier "my_evaluator"
        higher_is_better true

        def evaluate(input:, output:, context: nil)
          result(score: 0.9, reason: "Good")
        end
      end

      evaluator = klass.new
      result = evaluator.evaluate(input: "test", output: "test")

      expect(result.to_h).must_equal({
        evaluator: "my_evaluator",
        score: 0.9,
        reason: "Good",
        metadata: {},
        higher_is_better: true
      })
    end

    it "creates a Result with higher_is_better from evaluator" do
      klass = Class.new(Riffer::Evals::Evaluator) do
        identifier "toxicity"
        higher_is_better false

        def evaluate(input:, output:, context: nil)
          result(score: 0.1, reason: "Low toxicity")
        end
      end

      evaluator = klass.new
      result = evaluator.evaluate(input: "test", output: "test")

      expect(result.higher_is_better).must_equal false
    end
  end
end
