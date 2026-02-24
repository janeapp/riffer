# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::EvaluatorRunner do
  let(:evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true

      def evaluate(input:, output:, ground_truth: nil)
        score = [output.length / 100.0, 1.0].min
        result(score: score, reason: "Based on output length")
      end
    end
  end

  let(:ground_truth_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true

      def evaluate(input:, output:, ground_truth: nil)
        score = (ground_truth == output) ? 1.0 : 0.5
        result(score: score, reason: "Ground truth match")
      end
    end
  end

  let(:agent_class) do
    Class.new(Riffer::Agent) do
      model "mock/mock-model"
      instructions "You are a helpful assistant."
    end
  end

  before do
    Riffer::Providers::Repository.register("mock", Riffer::Providers::Mock) unless Riffer::Providers::Repository.find("mock")
  end

  describe ".run" do
    it "returns a RunResult" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{input: "What is Ruby?"}],
        evaluators: [evaluator_class]
      )

      expect(result).must_be_instance_of Riffer::Evals::RunResult
    end

    it "runs all scenarios" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [
          {input: "What is Ruby?"},
          {input: "What is Python?"}
        ],
        evaluators: [evaluator_class]
      )

      expect(result.scenario_results.length).must_equal 2
    end

    it "runs all evaluators per scenario" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{input: "What is Ruby?"}],
        evaluators: [evaluator_class, ground_truth_evaluator_class]
      )

      expect(result.scenario_results.first.results.length).must_equal 2
    end

    it "passes ground_truth to evaluators" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{input: "test", ground_truth: "Mock response"}],
        evaluators: [ground_truth_evaluator_class]
      )

      expect(result.scenario_results.first.results.first.score).must_equal 1.0
    end

    it "captures agent output in scenario results" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{input: "Hello"}],
        evaluators: [evaluator_class]
      )

      expect(result.scenario_results.first.output).must_equal "Mock response"
    end

    it "returns aggregate scores" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [
          {input: "What is Ruby?"},
          {input: "What is Python?"}
        ],
        evaluators: [evaluator_class]
      )

      expect(result.scores[evaluator_class]).must_be_instance_of Float
    end
  end

  describe "tool_context" do
    it "passes tool_context to agent" do
      received_context = nil
      context_agent = Class.new(Riffer::Agent) do
        model ->(ctx) {
          received_context = ctx
          "mock/mock-model"
        }
        instructions "You are a helpful assistant."
      end

      Riffer::Evals::EvaluatorRunner.run(
        agent: context_agent,
        scenarios: [{input: "Hello"}],
        evaluators: [evaluator_class],
        tool_context: {user_id: 42}
      )

      expect(received_context).must_equal({user_id: 42})
    end

    it "allows per-scenario tool_context to override top-level" do
      received_contexts = []
      context_agent = Class.new(Riffer::Agent) do
        model ->(ctx) {
          received_contexts << ctx
          "mock/mock-model"
        }
        instructions "You are a helpful assistant."
      end

      Riffer::Evals::EvaluatorRunner.run(
        agent: context_agent,
        scenarios: [
          {input: "Hello", tool_context: {user_id: 99}},
          {input: "Hi"}
        ],
        evaluators: [evaluator_class],
        tool_context: {user_id: 42}
      )

      expect(received_contexts[0]).must_equal({user_id: 99})
      expect(received_contexts[1]).must_equal({user_id: 42})
    end
  end

  describe "validation" do
    it "raises error when agent is not an Agent subclass" do
      expect {
        Riffer::Evals::EvaluatorRunner.run(
          agent: String,
          scenarios: [{input: "test"}],
          evaluators: [evaluator_class]
        )
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises error when eval is not an Evaluator subclass" do
      expect {
        Riffer::Evals::EvaluatorRunner.run(
          agent: agent_class,
          scenarios: [{input: "test"}],
          evaluators: [String]
        )
      }.must_raise(Riffer::ArgumentError)
    end
  end
end
