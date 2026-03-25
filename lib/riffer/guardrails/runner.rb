# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Guardrails::Runner
  attr_reader :guardrail_configs #: Array[Hash[Symbol, untyped]]

  attr_reader :phase #: Symbol

  attr_reader :context #: untyped

  #: (Array[Hash[Symbol, untyped]], phase: Symbol, ?context: untyped) -> void
  def initialize(guardrail_configs, phase:, context: nil)
    @guardrail_configs = guardrail_configs
    @phase = phase
    @context = context
  end

  #: (untyped, ?messages: Array[Riffer::Messages::Base]?) -> [untyped, Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run(data, messages: nil)
    current_data = data
    modifications = [] #: Array[Riffer::Guardrails::Modification]

    guardrail_configs.each do |config|
      guardrail = instantiate_guardrail(config)
      result = execute_guardrail(guardrail, current_data, messages: messages)

      if result.block?
        tripwire = Riffer::Guardrails::Tripwire.new(
          reason: result.data,
          guardrail: guardrail.class,
          phase: phase,
          metadata: result.metadata
        )
        return [current_data, tripwire, modifications]
      end

      if result.transform?
        modifications << Riffer::Guardrails::Modification.new(
          guardrail: guardrail.class,
          phase: phase,
          message_indices: detect_changed_indices(current_data, result.data)
        )
      end

      current_data = result.data
    end

    [current_data, nil, modifications]
  end

  private

  #: (Hash[Symbol, untyped]) -> Riffer::Guardrail
  def instantiate_guardrail(config)
    config[:class].new(**config[:options])
  end

  #: (untyped, untyped) -> Array[Integer]
  def detect_changed_indices(old_data, new_data)
    if old_data.is_a?(Array) && new_data.is_a?(Array)
      max_len = [old_data.length, new_data.length].max
      (0...max_len).select { |i| old_data[i] != new_data[i] }
    else
      (old_data == new_data) ? [] : [0]
    end
  end

  #: (Riffer::Guardrail, untyped, messages: Array[Riffer::Messages::Base]?) -> Riffer::Guardrails::Result
  def execute_guardrail(guardrail, data, messages:)
    case phase
    when :before
      guardrail.process_input(data, context: context)
    when :after
      guardrail.process_output(data, messages: messages, context: context)
    else
      raise Riffer::Error, "Unexpected guardrail phase: #{phase}. Valid phases: #{Riffer::Guardrails::PHASES.join(", ")}"
    end
  end
end
