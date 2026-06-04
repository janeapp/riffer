# frozen_string_literal: true
# rbs_inline: enabled

# Orchestrates running evaluators against an agent across multiple scenarios.
#
#   result = Riffer::Evals::EvaluatorRunner.run(
#     agent: MyAgent,
#     scenarios: [
#       { input: "What is Ruby?", ground_truth: "A programming language" },
#       { input: "What is Python?" }
#     ],
#     evaluators: [AnswerRelevancyEvaluator]
#   )
#
#   result.scores   # => { AnswerRelevancyEvaluator => 0.85 }
#
module Riffer::Evals::EvaluatorRunner
  extend self

  # Runs evaluators against an agent for the given scenarios. Raises
  # Riffer::ArgumentError on an invalid agent or evaluator.
  #--
  #: (agent: singleton(Riffer::Agent), scenarios: Array[Hash[Symbol, untyped]], evaluators: Array[singleton(Riffer::Evals::Evaluator)], ?context: Hash[Symbol, untyped]?) -> Riffer::Evals::RunResult
  def run(agent:, scenarios:, evaluators:, context: nil)
    validate_agent!(agent)
    validate_evaluators!(evaluators)

    scenario_results = scenarios.map do |scenario|
      run_scenario(agent: agent, scenario: scenario, evaluators: evaluators, context: context)
    end

    Riffer::Evals::RunResult.new(scenario_results: scenario_results)
  end

  private

  #--
  #: (singleton(Riffer::Agent)) -> void
  def validate_agent!(agent)
    return if agent.is_a?(Class) && agent < Riffer::Agent

    raise Riffer::ArgumentError, "agent must be a subclass of Riffer::Agent, got #{agent.inspect}"
  end

  #--
  #: (Array[singleton(Riffer::Evals::Evaluator)]) -> void
  def validate_evaluators!(evaluators)
    evaluators.each do |evaluator_class|
      next if evaluator_class.is_a?(Class) && evaluator_class < Riffer::Evals::Evaluator

      raise Riffer::ArgumentError, "each evaluator must be a subclass of Riffer::Evals::Evaluator, got #{evaluator_class.inspect}"
    end
  end

  #--
  #: (agent: singleton(Riffer::Agent), scenario: Hash[Symbol, untyped], evaluators: Array[singleton(Riffer::Evals::Evaluator)], ?context: Hash[Symbol, untyped]?) -> Riffer::Evals::ScenarioResult
  def run_scenario(agent:, scenario:, evaluators:, context: nil)
    input = scenario[:input]
    ground_truth = scenario[:ground_truth]
    resolved_context = scenario[:context] || context

    response = agent.generate(input, context: resolved_context)
    output = response.content
    messages = response.messages

    results = evaluators.map do |evaluator_class|
      evaluator_class.new.evaluate(input: input, output: output, ground_truth: ground_truth, messages: messages)
    end

    Riffer::Evals::ScenarioResult.new(
      input: input,
      output: output,
      ground_truth: ground_truth,
      results: results,
      messages: messages
    )
  end
end
