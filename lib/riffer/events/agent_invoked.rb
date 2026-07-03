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
  #: (agent: String, provider: String, duration: Float, steps: Integer, ?model: String?, ?token_usage: Riffer::Providers::TokenUsage?, ?error: Exception?, ?error_type: String?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(agent:, provider:, duration:, steps:, model: nil, token_usage: nil, error: nil, error_type: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error: error, error_type: error_type, tags: tags, trace_id: trace_id, span_id: span_id)
    @agent = agent
    @provider = provider
    @model = model
    @token_usage = token_usage
    @steps = steps
  end

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

  # Agent, provider, and model, on top of the shared dimensions.
  #--
  #: () -> Hash[String, String]
  def dimensions
    dims = super
    dims["agent"] = agent
    dims["provider"] = provider
    dims["model"] = model if model
    dims
  end

  # Duration and step count, plus aggregate token counts and cost when reported.
  #--
  #: () -> Hash[String, Numeric]
  def measurements
    values = super
    values["steps"] = steps
    if (usage = token_usage)
      values["input_tokens"] = usage.input_tokens
      values["output_tokens"] = usage.output_tokens
    end
    run_cost = cost
    values["cost"] = run_cost if run_cost
    values
  end
end
