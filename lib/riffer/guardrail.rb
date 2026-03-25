# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Guardrail
  #: (Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
  def process_input(messages, context:)
    pass(messages)
  end

  #: (Riffer::Messages::Assistant, messages: Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
  def process_output(response, messages:, context:)
    pass(response)
  end

  protected

  #: (untyped) -> Riffer::Guardrails::Result
  def pass(data)
    Riffer::Guardrails::Result.pass(data)
  end

  #: (untyped) -> Riffer::Guardrails::Result
  def transform(data)
    Riffer::Guardrails::Result.transform(data)
  end

  #: (String, ?metadata: Hash[Symbol, untyped]?) -> Riffer::Guardrails::Result
  def block(reason, metadata: nil)
    Riffer::Guardrails::Result.block(reason, metadata: metadata)
  end
end
