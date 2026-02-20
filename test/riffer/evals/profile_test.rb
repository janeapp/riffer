# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Profile do
  # Create a simple evaluator for testing
  let(:profile_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      higher_is_better true

      def evaluate(input:, output:, ground_truth: nil)
        # Simple scoring based on output containing the word from input
        score = output.downcase.include?(input.downcase.split.first) ? 0.9 : 0.5
        result(score: score, reason: "Test evaluation")
      end
    end
  end

  describe "ai_evals DSL" do
    it "defines metrics" do
      evaluator = profile_evaluator_class
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric evaluator, min: 0.8
        end
      end

      expect(profile_module.eval_metrics.length).must_equal 1
      expect(profile_module.eval_metrics.first.evaluator_class).must_equal profile_evaluator_class
      expect(profile_module.eval_metrics.first.min).must_equal 0.8
    end

    it "supports multiple metrics" do
      evaluator = profile_evaluator_class
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric evaluator, min: 0.85
          metric evaluator, max: 0.10
        end
      end

      expect(profile_module.eval_metrics.length).must_equal 2
    end

    it "supports weight option" do
      evaluator = profile_evaluator_class
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric evaluator, min: 0.8, weight: 2.0
        end
      end

      expect(profile_module.eval_metrics.first.weight).must_equal 2.0
    end
  end

  describe "Agent integration" do
    before do
      # Ensure mock provider is registered
      Riffer::Providers::Repository.register("mock", Riffer::Providers::Mock) unless Riffer::Providers::Repository.find("mock")
    end

    it "adds run_eval method when included in Agent" do
      evaluator = profile_evaluator_class
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric evaluator, min: 0.8
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/mock-model"
        instructions "You are a helpful assistant."
      end

      agent_class.include(profile_module)

      expect(agent_class.respond_to?(:run_eval)).must_equal true
    end

    it "runs evaluation when eval is called" do
      evaluator = profile_evaluator_class
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric evaluator, min: 0.8
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/mock-model"
        instructions "You are a helpful assistant."
      end

      agent_class.include(profile_module)

      # The test provider returns "Mock response" by default
      result = agent_class.run_eval(input: "What is Ruby?")

      expect(result).must_be_instance_of Riffer::Evals::RunResult
      expect(result.input).must_equal "What is Ruby?"
      expect(result.output).must_equal "Mock response"
    end

    it "accepts a messages array as input" do
      evaluator = Class.new(Riffer::Evals::Evaluator) do
        higher_is_better true

        def evaluate(input:, output:, ground_truth: nil)
          result(score: 0.9, reason: "Test evaluation")
        end
      end

      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric evaluator, min: 0.8
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "mock/mock-model"
        instructions "You are a helpful assistant."
      end

      agent_class.include(profile_module)

      messages = [
        {role: "user", content: "What is Ruby?"},
        {role: "assistant", content: "Ruby is a programming language."},
        {role: "user", content: "What makes it special?"}
      ]

      result = agent_class.run_eval(input: messages)

      expect(result).must_be_instance_of Riffer::Evals::RunResult
      expect(result.input).must_equal messages
      expect(result.output).must_equal "Mock response"
    end
  end

  describe "Builder" do
    it "creates metrics with correct options" do
      builder = Riffer::Evals::Profile::Builder.new
      builder.metric(profile_evaluator_class, min: 0.7, max: 0.95, weight: 1.5)

      metric = builder.metrics.first
      expect(metric.evaluator_class).must_equal profile_evaluator_class
      expect(metric.min).must_equal 0.7
      expect(metric.max).must_equal 0.95
      expect(metric.weight).must_equal 1.5
    end
  end
end
