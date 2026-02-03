# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Metric do
  describe "#initialize" do
    it "sets the evaluator_identifier" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "answer_relevancy")
      expect(metric.evaluator_identifier).must_equal "answer_relevancy"
    end

    it "converts evaluator_identifier to string" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: :answer_relevancy)
      expect(metric.evaluator_identifier).must_equal "answer_relevancy"
    end

    it "sets min as a float" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", min: "0.8")
      expect(metric.min).must_equal 0.8
    end

    it "sets max as a float" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", max: "0.2")
      expect(metric.max).must_equal 0.2
    end

    it "sets weight as a float" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", weight: 2)
      expect(metric.weight).must_equal 2.0
    end

    it "defaults weight to 1.0" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test")
      expect(metric.weight).must_equal 1.0
    end
  end

  describe "#evaluator_class" do
    it "looks up the evaluator from the registry" do
      # Reference the class first to trigger Zeitwerk autoload and registration
      evaluator_class = Riffer::Evals::Evaluators::AnswerRelevancy
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "answer_relevancy")
      expect(metric.evaluator_class).must_equal evaluator_class
    end

    it "returns nil for unknown evaluator" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "unknown_evaluator")
      expect(metric.evaluator_class).must_be_nil
    end
  end

  describe "#passes?" do
    it "passes when no thresholds set" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test")
      result = Riffer::Evals::Result.new(evaluator: "test", score: 0.5)
      expect(metric.passes?(result)).must_equal true
    end

    it "passes when score meets min threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", min: 0.8)
      result = Riffer::Evals::Result.new(evaluator: "test", score: 0.85)
      expect(metric.passes?(result)).must_equal true
    end

    it "fails when score below min threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", min: 0.8)
      result = Riffer::Evals::Result.new(evaluator: "test", score: 0.7)
      expect(metric.passes?(result)).must_equal false
    end

    it "passes when score meets max threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", max: 0.2)
      result = Riffer::Evals::Result.new(evaluator: "test", score: 0.1)
      expect(metric.passes?(result)).must_equal true
    end

    it "fails when score above max threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", max: 0.2)
      result = Riffer::Evals::Result.new(evaluator: "test", score: 0.3)
      expect(metric.passes?(result)).must_equal false
    end

    it "checks both min and max thresholds" do
      metric = Riffer::Evals::Metric.new(evaluator_identifier: "test", min: 0.4, max: 0.6)
      result_pass = Riffer::Evals::Result.new(evaluator: "test", score: 0.5)
      result_fail_low = Riffer::Evals::Result.new(evaluator: "test", score: 0.3)
      result_fail_high = Riffer::Evals::Result.new(evaluator: "test", score: 0.7)

      expect(metric.passes?(result_pass)).must_equal true
      expect(metric.passes?(result_fail_low)).must_equal false
      expect(metric.passes?(result_fail_high)).must_equal false
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      metric = Riffer::Evals::Metric.new(
        evaluator_identifier: "test",
        min: 0.8,
        max: nil,
        weight: 1.5
      )

      hash = metric.to_h
      expect(hash[:evaluator_identifier]).must_equal "test"
      expect(hash[:min]).must_equal 0.8
      expect(hash[:max]).must_be_nil
      expect(hash[:weight]).must_equal 1.5
    end
  end
end
