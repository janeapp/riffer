# frozen_string_literal: true
# rbs_inline: enabled

# Orchestrates running evaluators against an agent across multiple scenarios.
#
# Accepts an agent class, a list of scenarios, and evaluator classes.
# Generates agent output for each scenario and runs all evaluators,
# returning a RunResult with per-scenario details and aggregate scores.
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
class Riffer::Evals::EvaluatorRunner
  # Runs evaluators against an agent for the given scenarios.
  #
  # +agent+ - an Agent subclass (not an instance).
  # +scenarios+ - array of hashes with +:input+, optional +:ground_truth+, and optional +:tool_context+.
  # +evaluators+ - array of Evaluator subclasses to run against each scenario.
  # +tool_context+ - optional hash passed to +agent.generate+. Per-scenario +:tool_context+ takes precedence.
  #
  # Raises Riffer::ArgumentError if agent is not a Riffer::Agent subclass
  # or any eval is not a Riffer::Evals::Evaluator subclass.
  #
  #: (agent: singleton(Riffer::Agent), scenarios: Array[Hash[Symbol, untyped]], evaluators: Array[singleton(Riffer::Evals::Evaluator)], ?tool_context: Hash[Symbol, untyped]?) -> Riffer::Evals::RunResult
  def self.run(agent:, scenarios:, evaluators:, tool_context: nil)
    validate_agent!(agent)
    validate_evaluators!(evaluators)

    scenario_results = scenarios.map do |scenario|
      run_scenario(agent: agent, scenario: scenario, evaluators: evaluators, tool_context: tool_context)
    end

    Riffer::Evals::RunResult.new(scenario_results: scenario_results)
  end

  #: (singleton(Riffer::Agent)) -> void
  private_class_method def self.validate_agent!(agent)
    return if agent.is_a?(Class) && agent < Riffer::Agent

    raise Riffer::ArgumentError, "agent must be a subclass of Riffer::Agent, got #{agent.inspect}"
  end

  #: (Array[singleton(Riffer::Evals::Evaluator)]) -> void
  private_class_method def self.validate_evaluators!(evaluators)
    evaluators.each do |evaluator_class|
      next if evaluator_class.is_a?(Class) && evaluator_class < Riffer::Evals::Evaluator

      raise Riffer::ArgumentError, "each evaluator must be a subclass of Riffer::Evals::Evaluator, got #{evaluator_class.inspect}"
    end
  end

  #: (agent: singleton(Riffer::Agent), scenario: Hash[Symbol, untyped], evaluators: Array[singleton(Riffer::Evals::Evaluator)], ?tool_context: Hash[Symbol, untyped]?) -> Riffer::Evals::ScenarioResult
  private_class_method def self.run_scenario(agent:, scenario:, evaluators:, tool_context: nil)
    input = scenario[:input]
    ground_truth = scenario[:ground_truth]
    context = scenario[:tool_context] || tool_context

    response = agent.generate(input, tool_context: context)
    output = response.content

    results = evaluators.map do |evaluator_class|
      evaluator_class.new.evaluate(input: input, output: output, ground_truth: ground_truth)
    end

    Riffer::Evals::ScenarioResult.new(
      input: input,
      output: output,
      ground_truth: ground_truth,
      results: results
    )
  end
end
