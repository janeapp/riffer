# frozen_string_literal: true
# rbs_inline: enabled

# Wraps an agent generation response. +outcome+ says how the run ended; when a
# guardrail blocks execution, +content+ is empty and +tripwire+ carries the
# block details.
#
#   response = agent.generate("Hello")
#   if response.outcome.success?
#     puts response.content
#   else
#     puts "#{response.outcome.reason}: #{response.outcome.detail}"
#   end
class Riffer::Agent::Response
  # The response content.
  attr_reader :content #: String

  # How the run ended.
  attr_reader :outcome #: Riffer::Agent::Outcome

  # The tripwire if execution was blocked.
  attr_reader :tripwire #: Riffer::Guardrails::Tripwire?

  # The modifications made by guardrails during processing.
  attr_reader :modifications #: Array[Riffer::Guardrails::Modification]

  # The parsed structured output, if structured output was configured.
  attr_reader :structured_output #: Hash[Symbol, untyped]?

  # The aggregate token usage across this run's LLM calls, if any was reported.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  # The number of LLM calls made during this run (0 when a before-guardrail
  # blocks before any call). Distinct from the session's cumulative step count.
  attr_reader :steps #: Integer

  # The full message history from the agent conversation.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  # Call ids of tool_use blocks riffer filled with placeholder results this
  # turn (when an interrupt left them unanswered and history healing is on).
  attr_reader :healed_tool_call_ids #: Array[String]

  #--
  #: (
  #    String,
  #    outcome: Riffer::Agent::Outcome,
  #    ?tripwire: Riffer::Guardrails::Tripwire?,
  #    ?modifications: Array[Riffer::Guardrails::Modification],
  #    ?structured_output: Hash[Symbol, untyped]?,
  #    ?messages: Array[Riffer::Messages::Base],
  #    ?healed_tool_call_ids: Array[String],
  #    ?token_usage: Riffer::Providers::TokenUsage?,
  #    ?steps: Integer
  #  ) -> void
  def initialize(
    content,
    outcome:,
    tripwire: nil,
    modifications: [],
    structured_output: nil,
    messages: [],
    healed_tool_call_ids: [],
    token_usage: nil,
    steps: 0
  )
    @content = content
    @outcome = outcome
    @tripwire = tripwire
    @modifications = modifications
    @structured_output = structured_output
    @messages = messages
    @healed_tool_call_ids = healed_tool_call_ids
    @token_usage = token_usage
    @steps = steps
  end

  # Returns true if any guardrail modified data during processing.
  #
  #--
  #: () -> bool
  def modified?
    modifications.any?
  end
end
