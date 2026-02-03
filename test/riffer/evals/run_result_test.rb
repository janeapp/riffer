# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::RunResult do
  let(:passing_result) do
    Riffer::Evals::Result.new(evaluator: "relevancy", score: 0.9, higher_is_better: true)
  end

  let(:failing_result) do
    Riffer::Evals::Result.new(evaluator: "relevancy", score: 0.6, higher_is_better: true)
  end

  let(:toxicity_result) do
    Riffer::Evals::Result.new(evaluator: "toxicity", score: 0.1, higher_is_better: false)
  end

  let(:passing_metric) do
    Riffer::Evals::Metric.new(evaluator_identifier: "relevancy", min: 0.8)
  end

  let(:failing_metric) do
    Riffer::Evals::Metric.new(evaluator_identifier: "relevancy", min: 0.8)
  end

  let(:toxicity_metric) do
    Riffer::Evals::Metric.new(evaluator_identifier: "toxicity", max: 0.2)
  end

  describe "#initialize" do
    it "sets all attributes" do
      run_result = Riffer::Evals::RunResult.new(
        input: "question",
        output: "answer",
        context: {key: "value"},
        results: [passing_result],
        metrics: [passing_metric]
      )

      expect(run_result.input).must_equal "question"
      expect(run_result.output).must_equal "answer"
      expect(run_result.context).must_equal({key: "value"})
      expect(run_result.results).must_equal [passing_result]
      expect(run_result.metrics).must_equal [passing_metric]
    end
  end

  describe "#passed?" do
    it "returns true when all metrics pass" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [passing_result],
        metrics: [passing_metric]
      )

      expect(run_result.passed?).must_equal true
    end

    it "returns false when any metric fails" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [failing_result],
        metrics: [failing_metric]
      )

      expect(run_result.passed?).must_equal false
    end

    it "handles mixed results" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [passing_result, failing_result],
        metrics: [passing_metric, failing_metric]
      )

      expect(run_result.passed?).must_equal false
    end
  end

  describe "#failures" do
    it "returns empty array when all pass" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [passing_result],
        metrics: [passing_metric]
      )

      expect(run_result.failures).must_be_empty
    end

    it "returns failing results" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [failing_result],
        metrics: [failing_metric]
      )

      expect(run_result.failures).must_equal [failing_result]
    end

    it "filters to only failing results" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [passing_result, failing_result],
        metrics: [passing_metric, failing_metric]
      )

      expect(run_result.failures.length).must_equal 1
      expect(run_result.failures.first).must_equal failing_result
    end
  end

  describe "#aggregate_score" do
    it "returns 0.0 for empty results" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [],
        metrics: []
      )

      expect(run_result.aggregate_score).must_equal 0.0
    end

    it "returns the score for single result" do
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [passing_result],
        metrics: [passing_metric]
      )

      expect(run_result.aggregate_score).must_equal 0.9
    end

    it "calculates weighted average" do
      metric1 = Riffer::Evals::Metric.new(evaluator_identifier: "a", weight: 2.0)
      metric2 = Riffer::Evals::Metric.new(evaluator_identifier: "b", weight: 1.0)

      result1 = Riffer::Evals::Result.new(evaluator: "a", score: 0.9, higher_is_better: true)
      result2 = Riffer::Evals::Result.new(evaluator: "b", score: 0.6, higher_is_better: true)

      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [result1, result2],
        metrics: [metric1, metric2]
      )

      # (0.9 * 2.0 + 0.6 * 1.0) / (2.0 + 1.0) = 2.4 / 3.0 = 0.8
      expect(run_result.aggregate_score).must_be_close_to 0.8, 0.0001
    end

    it "normalizes lower_is_better scores" do
      # For toxicity (lower is better), a score of 0.1 should become 0.9 for aggregation
      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [toxicity_result],
        metrics: [toxicity_metric]
      )

      # Toxicity score of 0.1, higher_is_better=false
      # Normalized: 1.0 - 0.1 = 0.9
      expect(run_result.aggregate_score).must_equal 0.9
    end

    it "combines higher_is_better and lower_is_better scores" do
      metric1 = Riffer::Evals::Metric.new(evaluator_identifier: "relevancy", weight: 1.0)
      metric2 = Riffer::Evals::Metric.new(evaluator_identifier: "toxicity", weight: 1.0)

      result1 = Riffer::Evals::Result.new(evaluator: "relevancy", score: 0.8, higher_is_better: true)
      result2 = Riffer::Evals::Result.new(evaluator: "toxicity", score: 0.2, higher_is_better: false)

      run_result = Riffer::Evals::RunResult.new(
        input: "test",
        output: "test",
        context: nil,
        results: [result1, result2],
        metrics: [metric1, metric2]
      )

      # relevancy: 0.8 (already normalized)
      # toxicity: 1.0 - 0.2 = 0.8 (inverted)
      # Average: (0.8 + 0.8) / 2 = 0.8
      expect(run_result.aggregate_score).must_equal 0.8
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      run_result = Riffer::Evals::RunResult.new(
        input: "question",
        output: "answer",
        context: {key: "value"},
        results: [passing_result],
        metrics: [passing_metric]
      )

      hash = run_result.to_h
      expect(hash[:input]).must_equal "question"
      expect(hash[:output]).must_equal "answer"
      expect(hash[:context]).must_equal({key: "value"})
      expect(hash[:passed]).must_equal true
      expect(hash[:aggregate_score]).must_equal 0.9
      expect(hash[:results].length).must_equal 1
    end
  end
end
