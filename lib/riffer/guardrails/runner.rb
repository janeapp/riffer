# frozen_string_literal: true
# rbs_inline: enabled

# Executes guardrails sequentially and manages the processing pipeline.
#
# The runner processes guardrails in order, passing the output of each
# to the next. If any guardrail blocks, execution stops and a tripwire
# is returned.
#
#   runner = Runner.new(guardrail_configs, phase: :input, context: tool_context)
#   data, tripwire, result = runner.run(messages)
class Riffer::Guardrails::Runner
  # The guardrail configs to execute.
  attr_reader :guardrail_configs #: Array[Hash[Symbol, untyped]]

  # The execution phase (:input or :output).
  attr_reader :phase #: Symbol

  # The context passed to guardrails.
  attr_reader :context #: untyped

  # Creates a new runner.
  #
  # +guardrail_configs+ - configs with :class and :options keys.
  # +phase+ - :input or :output.
  # +context+ - optional context to pass to guardrails.
  #
  #: (Array[Hash[Symbol, untyped]], phase: Symbol, ?context: untyped) -> void
  def initialize(guardrail_configs, phase:, context: nil)
    @guardrail_configs = guardrail_configs
    @phase = phase
    @context = context
  end

  # Runs the guardrails sequentially.
  #
  # For input phase, data should be an array of messages.
  # For output phase, data should be a response and messages must be provided.
  #
  # +data+ - the data to process (messages for input, response for output).
  # +messages+ - the conversation messages (required for output phase).
  #
  #: (untyped, ?messages: Array[Riffer::Messages::Base]?) -> [untyped, Riffer::Guardrails::Tripwire?, Riffer::Guardrails::Result?]
  def run(data, messages: nil)
    current_data = data
    last_result = nil

    guardrail_configs.each do |config|
      guardrail = instantiate_guardrail(config)
      result = execute_guardrail(guardrail, current_data, messages: messages)
      last_result = result

      if result.block?
        tripwire = Riffer::Guardrails::Tripwire.new(
          reason: result.data,
          guardrail_id: guardrail.identifier,
          phase: phase,
          metadata: result.metadata
        )
        return [current_data, tripwire, result]
      end

      current_data = result.data
    end

    [current_data, nil, last_result]
  end

  private

  #: (Hash[Symbol, untyped]) -> Riffer::Guardrail
  def instantiate_guardrail(config)
    config[:class].new(**config[:options])
  end

  #: (Riffer::Guardrail, untyped, messages: Array[Riffer::Messages::Base]?) -> Riffer::Guardrails::Result
  def execute_guardrail(guardrail, data, messages:)
    case phase
    when :input
      guardrail.process_input(data, context: context)
    when :output
      guardrail.process_output(data, messages: messages, context: context)
    else
      raise Riffer::Error, "Unexpected guardrail phase: #{phase}. Valid phases: #{Riffer::Guardrails::PHASES.join(", ")}"
    end
  end
end
