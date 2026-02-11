# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Runner do
  # Create a simple evaluator that returns a fixed score
  let(:runner_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      description "Test evaluator for runner tests"
      higher_is_better true

      def evaluate(input:, output:, context: nil)
        # Return a score based on output length
        score = [output.length / 100.0, 1.0].min
        result(score: score, reason: "Based on output length")
      end
    end
  end

  describe "#initialize" do
    it "sets the metrics" do
      metrics = [Riffer::Evals::Metric.new(evaluator_class: runner_evaluator_class)]
      runner = Riffer::Evals::Runner.new(metrics: metrics)
      expect(runner.metrics).must_equal metrics
    end
  end

  describe "#run" do
    it "returns a RunResult" do
      metrics = [Riffer::Evals::Metric.new(evaluator_class: runner_evaluator_class, min: 0.5)]
      runner = Riffer::Evals::Runner.new(metrics: metrics)

      result = runner.run(
        input: "What is Ruby?",
        output: "Ruby is a programming language designed for programmer happiness. It was created by Yukihiro Matsumoto.",
        context: nil
      )

      expect(result).must_be_instance_of Riffer::Evals::RunResult
    end

    it "runs all evaluators" do
      metrics = [
        Riffer::Evals::Metric.new(evaluator_class: runner_evaluator_class, min: 0.5),
        Riffer::Evals::Metric.new(evaluator_class: runner_evaluator_class, min: 0.3)
      ]
      runner = Riffer::Evals::Runner.new(metrics: metrics)

      result = runner.run(
        input: "test",
        output: "This is a test output with enough length to score reasonably well in our test evaluator.",
        context: nil
      )

      expect(result.results.length).must_equal 2
    end

    it "passes context to evaluators" do
      context_evaluator_class = Class.new(Riffer::Evals::Evaluator) do
        def evaluate(input:, output:, context: nil)
          score = context&.dig(:expected_score) || 0.5
          result(score: score, reason: "From context")
        end
      end

      metrics = [Riffer::Evals::Metric.new(evaluator_class: context_evaluator_class)]
      runner = Riffer::Evals::Runner.new(metrics: metrics)

      result = runner.run(
        input: "test",
        output: "test output",
        context: {expected_score: 0.95}
      )

      expect(result.results.first.score).must_equal 0.95
    end
  end
end
