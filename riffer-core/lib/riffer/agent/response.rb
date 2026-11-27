# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::Response
  attr_reader :content #: String # @dynamic content
  attr_reader :outcome #: Riffer::Agent::Outcome # @dynamic outcome
  attr_reader :tripwire #: Riffer::Guardrails::Tripwire? # @dynamic tripwire
  attr_reader :modifications #: Array[Riffer::Guardrails::Modification] # @dynamic modifications
  attr_reader :reasoning #: Array[Riffer::Messages::Assistant::ReasoningPart] # @dynamic reasoning
  attr_reader :structured_output #: Hash[Symbol, untyped]? # @dynamic structured_output
  attr_reader :token_usage #: Riffer::Providers::TokenUsage? # @dynamic token_usage
  attr_reader :steps #: Integer # @dynamic steps
  attr_reader :messages #: Array[Riffer::Messages::Base] # @dynamic messages

  #--
  #: (
  #    String,
  #    outcome: Riffer::Agent::Outcome,
  #    ?tripwire: Riffer::Guardrails::Tripwire?,
  #    ?modifications: Array[Riffer::Guardrails::Modification],
  #    ?reasoning: Array[Riffer::Messages::Assistant::ReasoningPart],
  #    ?structured_output: Hash[Symbol, untyped]?,
  #    ?messages: Array[Riffer::Messages::Base],
  #    ?token_usage: Riffer::Providers::TokenUsage?,
  #    ?steps: Integer
  #  ) -> void
  def initialize(
    content,
    outcome:,
    tripwire: nil,
    modifications: [],
    reasoning: [],
    structured_output: nil,
    messages: [],
    token_usage: nil,
    steps: 0
  )
    @content = content
    @outcome = outcome
    @tripwire = tripwire
    @modifications = modifications
    @reasoning = reasoning
    @structured_output = structured_output
    @messages = messages
    @token_usage = token_usage
    @steps = steps
  end

  #--
  #: () -> bool
  def modified?
    modifications.any?
  end
end
