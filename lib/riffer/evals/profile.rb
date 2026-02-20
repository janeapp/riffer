# frozen_string_literal: true
# rbs_inline: enabled

# Module factory providing the ai_evals DSL for defining eval profiles.
#
# Include this module in a module to create an eval profile that can be
# included in agents.
#
#   module EvalProfiles::QualityEvals
#     include Riffer::Evals::Profile
#
#     ai_evals do
#       metric Riffer::Evals::Evaluators::AnswerRelevancy, min: 0.85
#     end
#   end
#
#   class MyAgent < Riffer::Agent
#     include EvalProfiles::QualityEvals
#     model "openai/gpt-4o"
#   end
#
#   result = MyAgent.run_eval(input: "What is Ruby?")
#   result.passed?  # => true/false
#
module Riffer::Evals::Profile
  #: (Module) -> void
  def self.included(base)
    base.extend(ClassMethods)

    # When the profile module is included in an Agent, add the eval method
    base.define_singleton_method(:included) do |target|
      if target < Riffer::Agent
        target.extend(AgentClassMethods)
        target.instance_variable_set(:@eval_profile, base)
      end
    end
  end

  # DSL builder for configuring metrics within ai_evals block.
  class Builder
    # The configured metrics.
    attr_reader :metrics #: Array[Riffer::Evals::Metric]

    #: () -> void
    def initialize
      @metrics = []
    end

    # Defines a metric with thresholds.
    #
    #: (singleton(Riffer::Evals::Evaluator), ?min: Float?, ?max: Float?, ?weight: Float) -> void
    def metric(evaluator_class, min: nil, max: nil, weight: 1.0)
      metrics << Riffer::Evals::Metric.new(
        evaluator_class: evaluator_class,
        min: min,
        max: max,
        weight: weight
      )
    end
  end

  module ClassMethods
    # Defines the eval metrics for this profile.
    #
    #: () { () -> void } -> void
    def ai_evals(&block)
      builder = Builder.new
      builder.instance_eval(&block)
      @eval_metrics = builder.metrics
    end

    # Returns the configured metrics.
    #
    #: () -> Array[Riffer::Evals::Metric]
    def eval_metrics
      @eval_metrics || []
    end
  end

  module AgentClassMethods
    # Runs evaluations against the agent.
    #
    #: (input: String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base], ?ground_truth: String?, ?tool_context: Hash[Symbol, untyped]?) -> Riffer::Evals::RunResult
    def run_eval(input:, ground_truth: nil, tool_context: nil)
      profile = @eval_profile
      raise Riffer::ArgumentError, "No eval profile configured" unless profile

      metrics = profile.eval_metrics
      raise Riffer::ArgumentError, "No metrics configured in eval profile" if metrics.empty?

      # Generate output from agent
      response = generate(input, tool_context: tool_context)

      # Run evaluations
      runner = Riffer::Evals::Runner.new(metrics: metrics)
      runner.run(input: input, output: response.content, ground_truth: ground_truth)
    end
  end
end
