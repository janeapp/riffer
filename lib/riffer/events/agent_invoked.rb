# frozen_string_literal: true
# rbs_inline: enabled

# Published when an agent run completes. +token_usage+ and +cost+ are the run
# aggregate across every chat call; sum +ChatCompleted+ instead for per-call
# figures, never both, to avoid double-counting.
class Riffer::Events::AgentInvoked < Riffer::Events::Base
  # The agent identifier.
  attr_reader :agent #: String

  # The provider name, ideally a GenAI semconv value (e.g. +openai+).
  attr_reader :provider #: String

  # The requested model id, when one was set.
  attr_reader :model #: String?

  # The aggregate token usage across the run, when any was reported.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  # The number of LLM steps the run took.
  attr_reader :steps #: Integer

  #--
  #: (agent: String, provider: String, duration: Float, steps: Integer, ?model: String?, ?token_usage: Riffer::Providers::TokenUsage?, ?error_type: String?, ?error: Exception?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(agent:, provider:, duration:, steps:, model: nil, token_usage: nil, error_type: nil, error: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error_type: error_type, error: error, tags: tags, trace_id: trace_id, span_id: span_id)
    @agent = agent
    @provider = provider
    @model = model
    @token_usage = token_usage
    @steps = steps
  end

  # The operation identifier.
  #--
  #: () -> Symbol
  def operation = :invoke_agent

  # The dotted event name.
  #--
  #: () -> String
  def name = "riffer.invoke_agent"

  # The aggregate run cost in USD, when every call was priced.
  #--
  #: () -> Float?
  def cost
    token_usage&.cost
  end
end
