# frozen_string_literal: true
# rbs_inline: enabled

# Wraps an agent generation response. When a guardrail blocks execution,
# +content+ is empty and +tripwire+ carries the block details.
#
#   response = agent.generate("Hello")
#   if response.blocked?
#     puts "Blocked: #{response.tripwire.reason}"
#   else
#     puts response.content
#   end
class Riffer::Agent::Response
  # @rbs @interrupted: bool

  # The response content.
  attr_reader :content #: String

  # The tripwire if execution was blocked.
  attr_reader :tripwire #: Riffer::Guardrails::Tripwire?

  # The modifications made by guardrails during processing.
  attr_reader :modifications #: Array[Riffer::Guardrails::Modification]

  # The reason provided with the interrupt, if any.
  attr_reader :interrupt_reason #: (String | Symbol)?

  # The parsed structured output, if structured output was configured.
  attr_reader :structured_output #: Hash[Symbol, untyped]?

  # The full message history from the agent conversation.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  # Call ids of tool_use blocks riffer filled with placeholder results this
  # turn (when an interrupt left them unanswered and history healing is on).
  attr_reader :healed_tool_call_ids #: Array[String]

  #--
  #: (String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?messages: Array[Riffer::Messages::Base], ?healed_tool_call_ids: Array[String]) -> void
  def initialize(content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil, structured_output: nil, messages: [], healed_tool_call_ids: [])
    @content = content
    @tripwire = tripwire
    @modifications = modifications
    @interrupted = interrupted
    @interrupt_reason = interrupt_reason
    @structured_output = structured_output
    @messages = messages
    @healed_tool_call_ids = healed_tool_call_ids
  end

  # Returns true if the response was blocked by a guardrail.
  #
  #--
  #: () -> bool
  def blocked?
    !tripwire.nil?
  end

  # Returns true if any guardrail modified data during processing.
  #
  #--
  #: () -> bool
  def modified?
    modifications.any?
  end

  # Returns true if the agent loop was interrupted by a callback
  # via <tt>throw :riffer_interrupt</tt>.
  #
  #--
  #: () -> bool
  def interrupted?
    @interrupted
  end
end
