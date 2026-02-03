# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Result do
  describe "#initialize" do
    it "sets the evaluator" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8)
      expect(result.evaluator).must_equal "test_eval"
    end

    it "sets the score as a float" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: "0.85")
      expect(result.score).must_equal 0.85
    end

    it "sets the reason" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8, reason: "Good response")
      expect(result.reason).must_equal "Good response"
    end

    it "defaults reason to nil" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8)
      expect(result.reason).must_be_nil
    end

    it "sets metadata" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8, metadata: {key: "value"})
      expect(result.metadata).must_equal({key: "value"})
    end

    it "defaults metadata to empty hash" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8)
      expect(result.metadata).must_equal({})
    end

    it "sets higher_is_better" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8, higher_is_better: false)
      expect(result.higher_is_better).must_equal false
    end

    it "defaults higher_is_better to true" do
      result = Riffer::Evals::Result.new(evaluator: "test_eval", score: 0.8)
      expect(result.higher_is_better).must_equal true
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      result = Riffer::Evals::Result.new(
        evaluator: "test_eval",
        score: 0.85,
        reason: "Good",
        metadata: {key: "value"},
        higher_is_better: true
      )

      hash = result.to_h
      expect(hash[:evaluator]).must_equal "test_eval"
      expect(hash[:score]).must_equal 0.85
      expect(hash[:reason]).must_equal "Good"
      expect(hash[:metadata]).must_equal({key: "value"})
      expect(hash[:higher_is_better]).must_equal true
    end
  end
end
