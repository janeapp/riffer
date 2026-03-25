# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::Response
  attr_reader :content #: String

  attr_reader :tripwire #: Riffer::Guardrails::Tripwire?

  attr_reader :modifications #: Array[Riffer::Guardrails::Modification]

  attr_reader :interrupt_reason #: (String | Symbol)?

  attr_reader :structured_output #: Hash[Symbol, untyped]?

  attr_reader :messages #: Array[Riffer::Messages::Base]

  #: (String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?messages: Array[Riffer::Messages::Base]) -> void
  def initialize(content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil, structured_output: nil, messages: [])
    @content = content
    @tripwire = tripwire
    @modifications = modifications
    @interrupted = interrupted
    @interrupt_reason = interrupt_reason
    @structured_output = structured_output
    @messages = messages
  end

  #: () -> bool
  def blocked?
    !tripwire.nil?
  end

  #: () -> bool
  def modified?
    modifications.any?
  end

  #: () -> bool
  def interrupted?
    @interrupted
  end
end
