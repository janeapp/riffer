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
#     evals: [Riffer::Evals::Evaluators::AnswerRelevancy]
#   )
#
#   result.scores   # => { Riffer::Evals::Evaluators::AnswerRelevancy => 0.85 }
#   result.summary  # => { total_scenarios: 2 }
#
class Riffer::Evals::EvaluatorRunner
  # Runs evaluators against an agent for the given scenarios.
  #
  # +agent+ - an Agent subclass (not an instance).
  # +scenarios+ - array of hashes with +:input+ and optional +:ground_truth+.
  # +evals+ - array of Evaluator subclasses to run against each scenario.
  #
  # Raises Riffer::ArgumentError if agent is not a Riffer::Agent subclass
  # or any eval is not a Riffer::Evals::Evaluator subclass.
  #
  #: (agent: singleton(Riffer::Agent), scenarios: Array[Hash[Symbol, untyped]], evals: Array[singleton(Riffer::Evals::Evaluator)]) -> Riffer::Evals::RunResult
  def self.run(agent:, scenarios:, evals:)
    validate_agent!(agent)
    validate_evals!(evals)

    scenario_results = scenarios.map do |scenario|
      run_scenario(agent: agent, scenario: scenario, evals: evals)
    end

    Riffer::Evals::RunResult.new(scenario_results: scenario_results)
  end

  #: (singleton(Riffer::Agent)) -> void
  private_class_method def self.validate_agent!(agent)
    return if agent.is_a?(Class) && agent < Riffer::Agent

    raise Riffer::ArgumentError, "agent must be a subclass of Riffer::Agent, got #{agent.inspect}"
  end

  #: (Array[singleton(Riffer::Evals::Evaluator)]) -> void
  private_class_method def self.validate_evals!(evals)
    evals.each do |eval_class|
      next if eval_class.is_a?(Class) && eval_class < Riffer::Evals::Evaluator

      raise Riffer::ArgumentError, "each eval must be a subclass of Riffer::Evals::Evaluator, got #{eval_class.inspect}"
    end
  end

  #: (agent: singleton(Riffer::Agent), scenario: Hash[Symbol, untyped], evals: Array[singleton(Riffer::Evals::Evaluator)]) -> Riffer::Evals::ScenarioResult
  private_class_method def self.run_scenario(agent:, scenario:, evals:)
    input = scenario[:input]
    ground_truth = scenario[:ground_truth]

    response = agent.generate(input)
    output = response.content

    results = evals.map do |eval_class|
      eval_class.new.evaluate(input: input, output: output, ground_truth: ground_truth)
    end

    Riffer::Evals::ScenarioResult.new(
      input: input,
      output: output,
      ground_truth: ground_truth,
      results: results
    )
  end
end
