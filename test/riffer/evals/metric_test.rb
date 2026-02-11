# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Metric do
  let(:stub_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      description "Test evaluator"
      higher_is_better true
    end
  end

  describe "#initialize" do
    it "sets the evaluator_class" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class)
      expect(metric.evaluator_class).must_equal stub_evaluator_class
    end

    it "raises error for non-evaluator class" do
      expect {
        Riffer::Evals::Metric.new(evaluator_class: String)
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises error for non-class" do
      expect {
        Riffer::Evals::Metric.new(evaluator_class: "answer_relevancy")
      }.must_raise(Riffer::ArgumentError)
    end

    it "sets min as a float" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, min: "0.8")
      expect(metric.min).must_equal 0.8
    end

    it "sets max as a float" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, max: "0.2")
      expect(metric.max).must_equal 0.2
    end

    it "sets weight as a float" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, weight: 2)
      expect(metric.weight).must_equal 2.0
    end

    it "defaults weight to 1.0" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class)
      expect(metric.weight).must_equal 1.0
    end
  end

  describe "#evaluator_class" do
    it "returns the evaluator class" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class)
      expect(metric.evaluator_class).must_equal stub_evaluator_class
    end
  end

  describe "#passes?" do
    it "passes when no thresholds set" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class)
      result = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.5)
      expect(metric.passes?(result)).must_equal true
    end

    it "passes when score meets min threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, min: 0.8)
      result = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.85)
      expect(metric.passes?(result)).must_equal true
    end

    it "fails when score below min threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, min: 0.8)
      result = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.7)
      expect(metric.passes?(result)).must_equal false
    end

    it "passes when score meets max threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, max: 0.2)
      result = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.1)
      expect(metric.passes?(result)).must_equal true
    end

    it "fails when score above max threshold" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, max: 0.2)
      result = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.3)
      expect(metric.passes?(result)).must_equal false
    end

    it "checks both min and max thresholds" do
      metric = Riffer::Evals::Metric.new(evaluator_class: stub_evaluator_class, min: 0.4, max: 0.6)
      result_pass = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.5)
      result_fail_low = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.3)
      result_fail_high = Riffer::Evals::Result.new(evaluator: stub_evaluator_class, score: 0.7)

      expect(metric.passes?(result_pass)).must_equal true
      expect(metric.passes?(result_fail_low)).must_equal false
      expect(metric.passes?(result_fail_high)).must_equal false
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      metric = Riffer::Evals::Metric.new(
        evaluator_class: stub_evaluator_class,
        min: 0.8,
        max: nil,
        weight: 1.5
      )

      hash = metric.to_h
      expect(hash[:evaluator_class]).must_equal stub_evaluator_class
      expect(hash[:min]).must_equal 0.8
      expect(hash[:max]).must_be_nil
      expect(hash[:weight]).must_equal 1.5
    end
  end
end
