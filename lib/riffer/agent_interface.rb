# frozen_string_literal: true
# rbs_inline: enabled

# Declares the public method contract that any Riffer agent implementation must satisfy.
#
# Include this module in any class that wants to act as a Riffer agent.
# All methods raise +NotImplementedError+ unless overridden by the including class.
#
# Riffer::Agent already satisfies this contract. Third-party agent implementations
# (e.g. vendor-mediated agents) should include this module and override each method.
#
#   class MyExternalAgent
#     include Riffer::AgentInterface
#
#     def generate(prompt_or_messages, files: nil, context: nil)
#       # call the vendor API and return a Riffer::AgentResponse
#     end
#
#     # ...
#   end
#
module Riffer::AgentInterface
  # Generates a response for the given prompt or messages.
  #
  # [prompt_or_messages] a String prompt or Array of message objects.
  # [files] optional file attachments.
  # [context] optional context hash forwarded to tools, guardrails, and dynamic config.
  #
  #--
  #: ((String | Array[untyped]), ?files: Array[untyped]?, ?context: Hash[Symbol, untyped]?) -> Riffer::AgentResponse
  def generate(prompt_or_messages, files: nil, context: nil)
    raise NotImplementedError, "#{self.class}#generate is not implemented"
  end

  # Streams a response for the given prompt or messages.
  #
  # [prompt_or_messages] a String prompt or Array of message objects.
  # [files] optional file attachments.
  # [context] optional context hash forwarded to tools, guardrails, and dynamic config.
  #
  #--
  #: ((String | Array[untyped]), ?files: Array[untyped]?, ?context: Hash[Symbol, untyped]?) -> Enumerator[untyped, void]
  def stream(prompt_or_messages, files: nil, context: nil)
    raise NotImplementedError, "#{self.class}#stream is not implemented"
  end

  # Returns the message history for this agent.
  #
  #--
  #: () -> Array[Riffer::Messages::Base]
  def messages
    raise NotImplementedError, "#{self.class}#messages is not implemented"
  end

  # Returns cumulative token usage across all LLM calls.
  #
  #--
  #: () -> Riffer::TokenUsage?
  def token_usage
    raise NotImplementedError, "#{self.class}#token_usage is not implemented"
  end

  # Registers a callback invoked when messages are added during generation.
  #
  #--
  #: () { (Riffer::Messages::Base) -> void } -> self
  def on_message(&block)
    raise NotImplementedError, "#{self.class}#on_message is not implemented"
  end
end
