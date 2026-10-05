# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::EvaluatorRunner do
  let(:evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true

      def evaluate(input:, output:, ground_truth: nil, messages: [])
        score = [output.length / 100.0, 1.0].min
        result(score: score, reason: "Based on output length")
      end
    end
  end

  let(:ground_truth_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true

      def evaluate(input:, output:, ground_truth: nil, messages: [])
        score = ground_truth == output ? 1.0 : 0.5
        result(score: score, reason: "Ground truth match")
      end
    end
  end

  let(:agent_class) do
    stub_agent("Agent") do
      model "mock/mock-model"
      instructions "You are a helpful assistant."
    end
  end

  before do
    unless Riffer::Providers::Repository.find("mock")
      Riffer::Providers::Repository.register("mock", Riffer::Providers::Mock)
    end
  end

  describe ".run" do
    it "returns a RunResult" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "What is Ruby?" }],
        evaluators: [evaluator_class],
      )

      expect(result).must_be_instance_of Riffer::Evals::RunResult
    end

    it "runs all scenarios" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [
          { input: "What is Ruby?" },
          { input: "What is Python?" },
        ],
        evaluators: [evaluator_class],
      )

      expect(result.scenario_results.length).must_equal 2
    end

    it "runs all evaluators per scenario" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "What is Ruby?" }],
        evaluators: [evaluator_class, ground_truth_evaluator_class],
      )

      expect(result.scenario_results.first.results.length).must_equal 2
    end

    it "passes ground_truth to evaluators" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "test", ground_truth: "Mock response" }],
        evaluators: [ground_truth_evaluator_class],
      )

      expect(result.scenario_results.first.results.first.score).must_equal 1.0
    end

    it "captures agent output in scenario results" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "Hello" }],
        evaluators: [evaluator_class],
      )

      expect(result.scenario_results.first.output).must_equal "Mock response"
    end

    it "includes message history in scenario results" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "Hello" }],
        evaluators: [evaluator_class],
      )

      messages = result.scenario_results.first.messages

      expect(messages).wont_be_empty
      expect(messages.any?(Riffer::Messages::System)).must_equal true
      expect(messages.any?(Riffer::Messages::User)).must_equal true
      expect(messages.any?(Riffer::Messages::Assistant)).must_equal true
    end

    it "passes messages to evaluators" do
      received_messages = nil
      messages_evaluator = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true

        define_method(:evaluate) do |input:, output:, ground_truth: nil, messages: []|
          received_messages = messages
          result(score: 1.0, reason: "ok")
        end
      end

      Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "Hello" }],
        evaluators: [messages_evaluator],
      )

      expect(received_messages).wont_be_nil
      expect(received_messages).wont_be_empty
    end

    it "captures agent token usage on the scenario result" do
      usage_mock = Class.new(Riffer::Providers::Mock) do
        def initialize
          super(responses: [
            { content: "Answer", token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 15, output_tokens: 6) },
          ])
        end
      end
      Riffer::Providers::Repository.register(:usage_mock) { usage_mock }

      usage_agent = stub_agent("UsageAgent") do
        model "usage_mock/mock-model"
        instructions "You are a helpful assistant."
      end

      result = Riffer::Evals::EvaluatorRunner.run(
        agent: usage_agent,
        scenarios: [{ input: "Hello" }],
        evaluators: [evaluator_class],
      )

      expect(result.scenario_results.first.token_usage.total_tokens).must_equal 21
    ensure
      Riffer::Providers::Repository.unregister(:usage_mock)
    end

    it "returns aggregate scores" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [
          { input: "What is Ruby?" },
          { input: "What is Python?" },
        ],
        evaluators: [evaluator_class],
      )

      expect(result.scores[evaluator_class]).must_be_instance_of Float
    end
  end

  describe "run outcome and structured output" do
    let(:recording_evaluator) do
      received = {}
      evaluator = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true

        define_method(:evaluate) do |**kwargs|
          received.merge!(kwargs)
          result(score: 1.0)
        end
      end
      [evaluator, received]
    end

    def structured_agent(content)
      structured_mock = Class.new(Riffer::Providers::Mock) do
        define_method(:initialize) { super(responses: [{ content: content }]) }
      end
      Riffer::Providers::Repository.register(:structured_mock) { structured_mock }

      stub_agent("StructuredAgent") do
        model "structured_mock/mock-model"
        instructions "Classify the sentiment."
        structured_output { required :sentiment, String }
      end
    end

    after { Riffer::Providers::Repository.unregister(:structured_mock) }

    it "passes the outcome and validated structured output to evaluators" do
      evaluator, received = recording_evaluator

      Riffer::Evals::EvaluatorRunner.run(
        agent: structured_agent('{"sentiment":"positive"}'),
        scenarios: [{ input: "I love it" }],
        evaluators: [evaluator],
      )

      expect(received[:outcome].reason).must_equal :completed
      expect(received[:structured_output]).must_equal({ sentiment: "positive" })
    end

    it "exposes an invalid structured output outcome to evaluators" do
      evaluator, received = recording_evaluator

      Riffer::Evals::EvaluatorRunner.run(
        agent: structured_agent("not json"),
        scenarios: [{ input: "I love it" }],
        evaluators: [evaluator],
      )

      expect(received[:outcome].reason).must_equal :invalid_structured_output
      expect(received[:structured_output]).must_be_nil
    end

    it "records the outcome and structured output on the scenario result" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: structured_agent('{"sentiment":"positive"}'),
        scenarios: [{ input: "I love it" }],
        evaluators: [evaluator_class],
      )

      scenario = result.scenario_results.first

      expect(scenario.outcome.reason).must_equal :completed
      expect(scenario.structured_output).must_equal({ sentiment: "positive" })
    end

    it "passes structured ground truth through unchanged" do
      evaluator, received = recording_evaluator
      ground_truth = { sentiment: "positive" }

      Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "I love it", ground_truth: ground_truth }],
        evaluators: [evaluator],
      )

      expect(received[:ground_truth]).must_equal ground_truth
    end

    it "omits arguments an evaluator does not declare" do
      legacy_evaluator = Class.new(Riffer::Evals::Evaluator) do
        def evaluate(input:, output:, ground_truth: nil, messages: [])
          result(score: 1.0)
        end
      end

      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "Hello" }],
        evaluators: [legacy_evaluator],
      )

      expect(result.scores[legacy_evaluator]).must_equal 1.0
    end
  end

  describe "failing scenarios" do
    let(:failing_agent) do
      failing_mock = Class.new(Riffer::Providers::Mock) do
        def generate_text(**options)
          raise Riffer::Error, "unsupported feature" if options[:messages].to_s.include?("boom")

          super
        end
      end
      Riffer::Providers::Repository.register(:failing_mock) { failing_mock }

      stub_agent("FailingAgent") do
        model "failing_mock/mock-model"
        instructions "You are a helpful assistant."
      end
    end

    after { Riffer::Providers::Repository.unregister(:failing_mock) }

    it "records the error on the scenario result and keeps running" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: failing_agent,
        scenarios: [{ input: "boom" }, { input: "Hello" }],
        evaluators: [evaluator_class],
      )

      failed, succeeded = result.scenario_results

      expect(failed.error.message).must_equal "unsupported feature"
      expect(succeeded.error).must_be_nil
      expect(succeeded.output).must_equal "Mock response"
    end

    it "skips evaluators for the errored scenario" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: failing_agent,
        scenarios: [{ input: "boom" }],
        evaluators: [evaluator_class],
      )

      failed = result.scenario_results.first

      expect(failed.results).must_be_empty
      expect(failed.output).must_be_nil
    end
  end

  describe "latency" do
    it "records the generate duration from the clock" do
      ticks = [10.0, 10.25]

      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "Hello" }],
        evaluators: [evaluator_class],
        clock: -> { ticks.shift },
      )

      expect(result.scenario_results.first.latency).must_equal 0.25
    end

    it "measures with the monotonic clock by default" do
      result = Riffer::Evals::EvaluatorRunner.run(
        agent: agent_class,
        scenarios: [{ input: "Hello" }],
        evaluators: [evaluator_class],
      )

      expect(result.scenario_results.first.latency).must_be :>=, 0.0
    end
  end

  describe "context" do
    it "passes context to agent" do
      received_context = nil
      context_agent = stub_agent("ContextAgent") do
        model lambda { |context|
          received_context = context
          "mock/mock-model"
        }
        instructions "You are a helpful assistant."
      end

      Riffer::Evals::EvaluatorRunner.run(
        agent: context_agent,
        scenarios: [{ input: "Hello" }],
        evaluators: [evaluator_class],
        context: { user_id: 42 },
      )

      expect(received_context[:user_id]).must_equal 42
    end

    it "allows per-scenario context to override top-level" do
      received_contexts = []
      context_agent = stub_agent("ContextAgent") do
        model lambda { |context|
          received_contexts << context
          "mock/mock-model"
        }
        instructions "You are a helpful assistant."
      end

      Riffer::Evals::EvaluatorRunner.run(
        agent: context_agent,
        scenarios: [
          { input: "Hello", context: { user_id: 99 } },
          { input: "Hi" },
        ],
        evaluators: [evaluator_class],
        context: { user_id: 42 },
      )

      expect(received_contexts[0][:user_id]).must_equal 99
      expect(received_contexts[1][:user_id]).must_equal 42
    end
  end

  describe "validation" do
    it "raises error when agent is not an Agent subclass" do
      expect do
        Riffer::Evals::EvaluatorRunner.run(
          agent: String,
          scenarios: [{ input: "test" }],
          evaluators: [evaluator_class],
        )
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises error when eval is not an Evaluator subclass" do
      expect do
        Riffer::Evals::EvaluatorRunner.run(
          agent: agent_class,
          scenarios: [{ input: "test" }],
          evaluators: [String],
        )
      end.must_raise(Riffer::ArgumentError)
    end
  end
end
