# frozen_string_literal: true
# rbs_inline: enabled

# Executes guardrails sequentially, passing each one's output to the next; if
# any blocks, execution stops and a tripwire is returned.
class Riffer::Guardrails::Runner
  # The guardrail configs to execute.
  attr_reader :guardrail_configs #: Array[Hash[Symbol, untyped]]

  # The execution phase (:before or :after).
  attr_reader :phase #: Symbol

  # The context passed to guardrails.
  attr_reader :context #: untyped

  # The normalized per-call tags, stamped as +riffer.tag.*+ on guardrail spans.
  attr_reader :tags #: Hash[String, String]

  #--
  #: (Array[Hash[Symbol, untyped]], phase: Symbol, ?context: untyped, ?tags: Hash[String, String]) -> void
  def initialize(guardrail_configs, phase:, context: nil, tags: {})
    @guardrail_configs = guardrail_configs
    @phase = phase
    @context = context
    @tags = tags
  end

  # Runs the guardrails sequentially. For the +:before+ phase +data+ is the
  # messages array; for +:after+ it's the response (and +messages+ must be
  # provided).
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
      (0...max_len).select { |i| old_data[i] != new_data[i] }
    else
      (old_data == new_data) ? [] : [0]
    end
  end

  #--
  #: (Riffer::Guardrail, untyped, messages: Array[Riffer::Messages::Base]?) -> Riffer::Guardrails::Result
  def execute_guardrail(guardrail, data, messages:)
    Riffer::Events.observe(
      "execute_guardrail #{guardrail.name}",
      attributes: guardrail_span_attributes(guardrail),
      kind: :internal,
      event: ->(result, outcome) { build_guardrail_event(guardrail, result, outcome) }
    ) do |span|
      result = run_guardrail_phase(guardrail, data, messages: messages)
      record_guardrail_outcome(span, result)
      result
    end
  end

  # +result+ is nil when the guardrail raised, so +outcome+ is nil and the
  # error fields carry the failure instead.
  #--
  #: (Riffer::Guardrail, Riffer::Guardrails::Result?, Riffer::Events::Outcome) -> Riffer::Events::GuardrailExecuted
  def build_guardrail_event(guardrail, result, outcome)
    Riffer::Events::GuardrailExecuted.new(
      guardrail: guardrail.name,
      phase: phase,
      outcome: result&.type,
      tags: tags,
      **outcome.to_h
    )
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
      raise Riffer::Error, "Unexpected guardrail phase: #{phase}. Valid phases: #{Riffer::Guardrails::PHASES.join(", ")}"
    end
  end

  #--
  #: (Riffer::Guardrail) -> Hash[String, untyped]
  def guardrail_span_attributes(guardrail)
    {
      "riffer.guardrail.name" => guardrail.name,
      "riffer.guardrail.phase" => phase.to_s
    }.merge(tags.transform_keys { |key| "riffer.tag.#{key}" })
  end

  # A block is a handled outcome, so its span status stays unset — an error
  # span status is reserved for a raised exception.
  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Guardrails::Result) -> void
  def record_guardrail_outcome(span, result)
    span.set_attribute("riffer.guardrail.action", result.type.to_s)
    span.set_attribute("riffer.tripwire.reason", result.data) if result.block?
  end
end
