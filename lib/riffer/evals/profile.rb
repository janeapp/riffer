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
#       metric :answer_relevancy, min: 0.85
#       metric :hallucination, max: 0.10
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
  #: base: Module
  #: return: void
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

    #: return: void
    def initialize
      @metrics = []
    end

    # Defines a metric with thresholds.
    #
    #: identifier: (Symbol | String) -- the evaluator identifier
    #: min: Float? -- minimum score threshold
    #: max: Float? -- maximum score threshold
    #: weight: Float -- weight for aggregation (default: 1.0)
    #: return: void
    def metric(identifier, min: nil, max: nil, weight: 1.0)
      metrics << Riffer::Evals::Metric.new(
        evaluator_identifier: identifier,
        min: min,
        max: max,
        weight: weight
      )
    end
  end

  module ClassMethods
    # Defines the eval metrics for this profile.
    #
    #: &block: () -> void
    #: return: void
    def ai_evals(&block)
      builder = Builder.new
      builder.instance_eval(&block)
      @eval_metrics = builder.metrics
    end

    # Returns the configured metrics.
    #
    #: return: Array[Riffer::Evals::Metric]
    def eval_metrics
      @eval_metrics || []
    end
  end

  module AgentClassMethods
    # Runs evaluations against the agent.
    #
    #: input: String -- the input to send to the agent
    #: context: Hash[Symbol, untyped]? -- optional context for evaluation
    #: tool_context: Hash[Symbol, untyped]? -- optional context passed to tools during generation
    #: return: Riffer::Evals::RunResult
    def run_eval(input:, context: nil, tool_context: nil)
      profile = @eval_profile
      raise Riffer::ArgumentError, "No eval profile configured" unless profile

      metrics = profile.eval_metrics
      raise Riffer::ArgumentError, "No metrics configured in eval profile" if metrics.empty?

      # Generate output from agent
      output = generate(input, tool_context: tool_context)

      # Run evaluations
      runner = Riffer::Evals::Runner.new(metrics: metrics)
      runner.run(input: input, output: output, context: context)
    end
  end
end
