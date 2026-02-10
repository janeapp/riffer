# frozen_string_literal: true
# rbs_inline: enabled

# Base class for guardrails that process input and output in the agent pipeline.
#
# Subclass this to create custom guardrails:
#
#   class MyGuardrail < Riffer::Guardrail
#     identifier "my_guardrail"
#
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
  include Riffer::Helpers::ClassNameConverter

  class << self
    include Riffer::Helpers::ClassNameConverter

    # Gets or sets the guardrail identifier.
    #
    # +value+ - the identifier to set, or nil to get.
    #
    #: (?String?) -> String
    def identifier(value = nil)
      return @identifier || class_name_to_path(name) if value.nil?
      @identifier = value.to_s
    end
  end

  # Returns the instance's identifier.
  #
  #: () -> String
  def identifier
    self.class.identifier
  end

  # Processes input messages before they are sent to the LLM.
  #
  # Override this method in subclasses to implement input processing.
  #
  # +messages+ - the input messages.
  # +context+ - optional context passed to the agent.
  #
  #: (Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
  def process_input(messages, context:)
    pass(messages)
  end

  # Processes output response after it is received from the LLM.
  #
  # Override this method in subclasses to implement output processing.
  #
  # +response+ - the LLM response.
  # +messages+ - the conversation messages.
  # +context+ - optional context passed to the agent.
  #
  #: (Riffer::Messages::Assistant, messages: Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
  def process_output(response, messages:, context:)
    pass(response)
  end

  protected

  # Creates a pass result that continues with unchanged data.
  #
  # +data+ - the original data to pass through.
  #
  #: (untyped) -> Riffer::Guardrails::Result
  def pass(data)
    Riffer::Guardrails::Result.pass(data)
  end

  # Creates a transform result that continues with transformed data.
  #
  # +data+ - the transformed data.
  #
  #: (untyped) -> Riffer::Guardrails::Result
  def transform(data)
    Riffer::Guardrails::Result.transform(data)
  end

  # Creates a block result that halts execution.
  #
  # +reason+ - the reason for blocking.
  # +metadata+ - optional additional information.
  #
  #: (String, ?metadata: Hash[Symbol, untyped]?) -> Riffer::Guardrails::Result
  def block(reason, metadata: nil)
    Riffer::Guardrails::Result.block(reason, metadata: metadata)
  end
end
