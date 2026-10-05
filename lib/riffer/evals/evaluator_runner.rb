# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Evals::EvaluatorRunner
  extend self

  MONOTONIC_CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) } #: ^() -> Float

  KEYWORD_PARAMETER_TYPES = %i[key keyreq].freeze #: Array[Symbol]

  #--
  #: (agent: singleton(Riffer::Agent), scenarios: Array[Hash[Symbol, untyped]], evaluators: Array[singleton(Riffer::Evals::Evaluator)], ?context: Hash[Symbol, untyped]?, ?clock: ^() -> Float) -> Riffer::Evals::RunResult
  def run(agent:, scenarios:, evaluators:, context: nil, clock: MONOTONIC_CLOCK)
    validate_agent!(agent)
    validate_evaluators!(evaluators)

    scenario_results = scenarios.map do |scenario|
      run_scenario(agent: agent, scenario: scenario, evaluators: evaluators, context: context, clock: clock)
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

      raise Riffer::ArgumentError,
            "each evaluator must be a subclass of Riffer::Evals::Evaluator, got #{evaluator_class.inspect}"
    end
  end

  #--
  #: (agent: singleton(Riffer::Agent), scenario: Hash[Symbol, untyped], evaluators: Array[singleton(Riffer::Evals::Evaluator)], context: Hash[Symbol, untyped]?, clock: ^() -> Float) -> Riffer::Evals::ScenarioResult
  def run_scenario(agent:, scenario:, evaluators:, context:, clock:)
    input = scenario[:input]
    ground_truth = scenario[:ground_truth]

    started_at = clock.call
    response_or_error = generate(agent, input, context: scenario[:context] || context)
    latency = clock.call - started_at

    if response_or_error.is_a?(StandardError)
      return Riffer::Evals::ScenarioResult.new(
        input: input,
        output: nil,
        ground_truth: ground_truth,
        results: [],
        latency: latency,
        error: response_or_error,
      )
    end

    response = response_or_error
    evaluator_args = {
      input: input,
      output: response.content,
      ground_truth: ground_truth,
      messages: response.messages,
      outcome: response.outcome,
      structured_output: response.structured_output,
    } #: Hash[Symbol, untyped]

    results = evaluators.map do |evaluator_class|
      evaluate = evaluator_class.new.method(:evaluate)
      evaluate.call(**accepted_args(evaluate.parameters, evaluator_args))
    end

    Riffer::Evals::ScenarioResult.new(
      input: input,
      output: response.content,
      ground_truth: ground_truth,
      results: results,
      messages: response.messages,
      token_usage: response.token_usage,
      outcome: response.outcome,
      structured_output: response.structured_output,
      latency: latency,
    )
  end

  # A failed generation is that scenario's result, so one provider error
  # cannot abort the remaining scenarios.
  #--
  #: (singleton(Riffer::Agent), String, context: Hash[Symbol, untyped]?) -> (Riffer::Agent::Response | StandardError)
  def generate(agent, input, context:)
    agent.generate(input, context: context)
  rescue StandardError => e
    e
  end

  # Evaluators declare only the keywords they use; passing an undeclared one
  # would raise ArgumentError.
  #--
  #: (Array[untyped], Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def accepted_args(parameters, args)
    return args if parameters.any? { |type, _| type == :keyrest }

    args.slice(*parameters.filter_map { |type, name| name if KEYWORD_PARAMETER_TYPES.include?(type) })
  end
end
