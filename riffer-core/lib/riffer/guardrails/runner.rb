# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Guardrails::Runner
  attr_reader :guardrail_configs #: Array[Hash[Symbol, untyped]] # @dynamic guardrail_configs

  attr_reader :phase #: Symbol # @dynamic phase

  attr_reader :context #: untyped # @dynamic context

  attr_reader :tags #: Hash[String, String] # @dynamic tags

  #--
  #: (Array[Hash[Symbol, untyped]], phase: Symbol, ?context: untyped, ?tags: Hash[String, String]) -> void
  def initialize(guardrail_configs, phase:, context: nil, tags: {})
    @guardrail_configs = guardrail_configs
    @phase = phase
    @context = context
    @tags = tags
  end

  #--
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
          metadata: result.metadata,
        )
        return [current_data, tripwire, modifications]
      end

      if result.transform?
        modifications << Riffer::Guardrails::Modification.new(
          guardrail: guardrail.class,
          phase: phase,
          message_indices: detect_changed_indices(current_data, result.data),
        )
      end

      current_data = result.data
    end

    [current_data, nil, modifications]
  end

  private

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Guardrail
  def instantiate_guardrail(config)
    options = config[:options] #: Hash[Symbol, untyped]
    config[:class].new(**options)
  end

  #--
  #: (untyped, untyped) -> Array[Integer]
  def detect_changed_indices(old_data, new_data)
    if old_data.is_a?(Array) && new_data.is_a?(Array)
      max_len = [old_data.length, new_data.length].max
      (0...max_len).reject { |i| old_data[i] == new_data[i] }
    else
      old_data == new_data ? [] : [0]
    end
  end

  #--
  #: (Riffer::Guardrail, untyped, messages: Array[Riffer::Messages::Base]?) -> Riffer::Guardrails::Result
  def execute_guardrail(guardrail, data, messages:)
    Riffer::Tracing.in_span(
      "execute_guardrail #{guardrail.name}",
      attributes: guardrail_span_attributes(guardrail),
      kind: :internal,
    ) do |span|
      result = run_guardrail_phase(guardrail, data, messages: messages)
      record_guardrail_outcome(span, result)
      result
    rescue StandardError => e
      # The backend records the exception and error status on the re-raise;
      # error.type is the one semconv attribute it doesn't set.
      span.set_attribute("error.type", e.class.name)
      raise
    end
  end

  #--
  #: (Riffer::Guardrail, untyped, messages: Array[Riffer::Messages::Base]?) -> Riffer::Guardrails::Result
  def run_guardrail_phase(guardrail, data, messages:)
    case phase
    when :before
      guardrail.process_input(data, context: context)
    when :after
      guardrail.process_output(data, messages: messages || [], context: context)
    else
      raise Riffer::Error,
            "Unexpected guardrail phase: #{phase}. Valid phases: #{Riffer::Guardrails::PHASES.join(', ')}"
    end
  end

  #--
  #: (Riffer::Guardrail) -> Hash[String, untyped]
  def guardrail_span_attributes(guardrail)
    {
      "riffer.guardrail.name" => guardrail.name,
      "riffer.guardrail.phase" => phase.to_s,
    }.merge(tags.transform_keys { |key| "riffer.tag.#{key}" })
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Guardrails::Result) -> void
  def record_guardrail_outcome(span, result)
    span.set_attribute("riffer.guardrail.action", result.type.to_s)
    # A block is a handled outcome, so span status stays unset — error status
    # is reserved for a raised exception.
    span.set_attribute("riffer.tripwire.reason", result.data) if result.block?
  end
end
