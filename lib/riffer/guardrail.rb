# frozen_string_literal: true
# rbs_inline: enabled

# Base class for guardrails that process input and output in the agent pipeline.
#
#   class MyGuardrail < Riffer::Guardrail
#     def process_input(messages, context:)
#       # Return pass(messages), transform(modified_messages), or block(reason)
#       pass(messages)
#     end
#
#     def process_output(response, messages:, context:)
#       # Return pass(response), transform(modified_response), or block(reason)
#       pass(response)
#     end
#   end
class Riffer::Guardrail
  # Processes input messages before they're sent to the LLM; override in
  # subclasses.
  #--
  #: (Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
  def process_input(messages, context:)
    pass(messages)
  end

  # Processes the output response after it's received from the LLM; override in
  # subclasses.
  #--
  #: (Riffer::Messages::Assistant, messages: Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
  def process_output(response, messages:, context:)
    pass(response)
  end

  # Returns the guardrail's identifier, used as the tracing span suffix and the
  # <tt>riffer.guardrail.name</tt> attribute; override to label the span.
  #--
  #: () -> String
  def name
    Riffer::Helpers::Identifier.for(self.class)
  end

  protected

  # Creates a pass result that continues with unchanged data.
  #--
  #: (untyped) -> Riffer::Guardrails::Result
  def pass(data)
    Riffer::Guardrails::Result.pass(data)
  end

  # Creates a transform result that continues with transformed data.
  #--
  #: (untyped) -> Riffer::Guardrails::Result
  def transform(data)
    Riffer::Guardrails::Result.transform(data)
  end

  # Creates a block result that halts execution.
  #--
  #: (String, ?metadata: Hash[Symbol, untyped]?) -> Riffer::Guardrails::Result
  def block(reason, metadata: nil)
    Riffer::Guardrails::Result.block(reason, metadata: metadata)
  end
end
