# frozen_string_literal: true
# rbs_inline: enabled

# Sequentially executes a workflow's steps, validating input/output at each
# boundary and capturing per-step results.
module Riffer::Workflow::Runner
  extend self

  # Runs the given step classes in order, threading each step's output into the
  # next step's input.
  #--
  #: (steps: Array[singleton(Riffer::Workflow::Step)], input: Hash[Symbol, untyped], ?context: Hash[Symbol, untyped]?) -> Riffer::Workflow::Result
  def execute(steps:, input:, context: nil)
    step_results = {} #: Hash[String, Riffer::Workflow::StepResult]
    current_input = input

    steps.each do |step_class|
      step_result = run_step(step_class, current_input, context)
      step_id = step_class.identifier

      step_results[step_id] = step_result

      unless step_result.success?
        mark_pending(steps, step_results)
        return Riffer::Workflow::Result.new(
          status: :failed,
          input: input,
          error: step_result.error,
          failed_step: step_id,
          steps: step_results
        )
      end

      current_input = step_result.output || current_input
    end

    Riffer::Workflow::Result.new(
      status: :success,
      input: input,
      output: current_input,
      steps: step_results
    )
  end

  private

  #--
  #: (singleton(Riffer::Workflow::Step), Hash[Symbol, untyped], Hash[Symbol, untyped]?) -> Riffer::Workflow::StepResult
  def run_step(step_class, input, context)
    step_instance = step_class.new(context: context)

    validated_input = validate_input(step_class, input)
    output = step_instance.execute(**validated_input)
    output = validate_output(step_class, output)

    Riffer::Workflow::StepResult.new(status: :success, payload: validated_input, output: output)
  rescue => e
    payload = defined?(validated_input) ? validated_input : input
    Riffer::Workflow::StepResult.new(status: :failed, payload: payload, error: e)
  end

  #--
  #: (singleton(Riffer::Workflow::Step), Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def validate_input(step_class, data)
    params = step_class.input
    return data unless params

    params.validate(data)
  end

  #--
  #: (singleton(Riffer::Workflow::Step), Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def validate_output(step_class, data)
    unless data.is_a?(Hash)
      raise Riffer::ValidationError, "#{step_class} must return a Hash from #execute, got #{data.class}"
    end

    params = step_class.output
    return data unless params

    params.validate(data)
  end

  # Marks remaining steps as pending after a failure.
  #--
  #: (Array[singleton(Riffer::Workflow::Step)], Hash[String, Riffer::Workflow::StepResult]) -> void
  def mark_pending(steps, step_results)
    steps.each do |step_class|
      step_id = step_class.identifier
      next if step_results.key?(step_id)

      step_results[step_id] = Riffer::Workflow::StepResult.new(status: :pending)
    end
  end
end
