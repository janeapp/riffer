# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Profile do
  # Create a simple evaluator for testing
  let(:profile_evaluator_class) do
    Class.new(Riffer::Evals::Evaluator) do
      identifier "profile_test_evaluator"
      description "Test evaluator for profile tests"
      higher_is_better true

      def evaluate(input:, output:, context: nil)
        # Simple scoring based on output containing the word from input
        score = output.downcase.include?(input.downcase.split.first) ? 0.9 : 0.5
        result(score: score, reason: "Test evaluation")
      end
    end
  end

  before do
    Riffer::Evals::Evaluators::Repository.register(:profile_test_evaluator, profile_evaluator_class)
  end

  after do
    Riffer::Evals::Evaluators::Repository.clear
  end

  describe "ai_evals DSL" do
    it "defines metrics" do
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric :profile_test_evaluator, min: 0.8
        end
      end

      expect(profile_module.eval_metrics.length).must_equal 1
      expect(profile_module.eval_metrics.first.evaluator_identifier).must_equal "profile_test_evaluator"
      expect(profile_module.eval_metrics.first.min).must_equal 0.8
    end

    it "supports multiple metrics" do
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric :profile_test_evaluator, min: 0.85
          metric :profile_test_evaluator, max: 0.10
        end
      end

      expect(profile_module.eval_metrics.length).must_equal 2
    end

    it "supports weight option" do
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric :profile_test_evaluator, min: 0.8, weight: 2.0
        end
      end

      expect(profile_module.eval_metrics.first.weight).must_equal 2.0
    end
  end

  describe "Agent integration" do
    before do
      # Ensure test provider is registered
      Riffer::Providers::Repository.register("test", Riffer::Providers::Test) unless Riffer::Providers::Repository.find("test")
    end

    it "adds run_eval method when included in Agent" do
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric :profile_test_evaluator, min: 0.8
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "test/test-model"
        instructions "You are a helpful assistant."
      end

      agent_class.include(profile_module)

      expect(agent_class.respond_to?(:run_eval)).must_equal true
    end

    it "runs evaluation when eval is called" do
      profile_module = Module.new do
        include Riffer::Evals::Profile

        ai_evals do
          metric :profile_test_evaluator, min: 0.8
        end
      end

      agent_class = Class.new(Riffer::Agent) do
        model "test/test-model"
        instructions "You are a helpful assistant."
      end

      agent_class.include(profile_module)

      # The test provider returns "Test response" by default
      result = agent_class.run_eval(input: "What is Ruby?")

      expect(result).must_be_instance_of Riffer::Evals::RunResult
      expect(result.input).must_equal "What is Ruby?"
      expect(result.output).must_equal "Test response"
    end
  end

  describe "Builder" do
    it "creates metrics with correct options" do
      builder = Riffer::Evals::Profile::Builder.new
      builder.metric(:test, min: 0.7, max: 0.95, weight: 1.5)

      metric = builder.metrics.first
      expect(metric.evaluator_identifier).must_equal "test"
      expect(metric.min).must_equal 0.7
      expect(metric.max).must_equal 0.95
      expect(metric.weight).must_equal 1.5
    end
  end
end
