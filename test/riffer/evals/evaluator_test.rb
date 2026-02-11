# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Evaluator do
  let(:evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      description "A test evaluator"
      higher_is_better true
    end
  end

  let(:lower_is_better_class) do
    Class.new(Riffer::Evals::Evaluator) do
      description "Detects toxicity"
      higher_is_better false
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
        higher_is_better true

        def evaluate(input:, output:, context: nil)
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
