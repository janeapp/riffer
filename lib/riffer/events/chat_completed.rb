# frozen_string_literal: true
# rbs_inline: enabled

# Published when a single LLM chat call completes, on success or failure.
class Riffer::Events::ChatCompleted < Riffer::Events::Base
  # The provider name, ideally a GenAI semconv value (e.g. +openai+).
  attr_reader :provider #: String

  # The requested model id, when one was set.
  attr_reader :model #: String?

  # Token usage for the call, when the provider reported it.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage?

  # The normalized finish reason, when the provider reported one.
  attr_reader :finish_reason #: Riffer::Providers::FinishReason?

  #--
  #: (provider: String, duration: Float, ?model: String?, ?token_usage: Riffer::Providers::TokenUsage?, ?finish_reason: Riffer::Providers::FinishReason?, ?error: Exception?, ?error_type: String?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(provider:, duration:, model: nil, token_usage: nil, finish_reason: nil, error: nil, error_type: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error: error, error_type: error_type, tags: tags, trace_id: trace_id, span_id: span_id)
    @provider = provider
    @model = model
    @token_usage = token_usage
    @finish_reason = finish_reason
  end

  # The dotted event name.
  #--
  #: () -> String
  def name = "riffer.chat"

  # The call cost in USD, when the model was priced.
  #--
  #: () -> Float?
  def cost
    token_usage&.cost
  end

  # Provider, model, and the normalized finish reason, on top of the shared
  # dimensions.
  #--
  #: () -> Hash[String, String]
  def dimensions
    dims = super
    dims["provider"] = provider
    dims["model"] = model if model
    dims["finish_reason"] = finish_reason.reason.to_s if finish_reason
    dims
  end

  # Duration, plus token counts and cost when the provider reported them.
  #--
  #: () -> Hash[String, Numeric]
  def measurements
    values = super
    if (usage = token_usage)
      values["input_tokens"] = usage.input_tokens
      values["output_tokens"] = usage.output_tokens
      values["cache_read_tokens"] = usage.cache_read_tokens if usage.cache_read_tokens
      values["cache_write_tokens"] = usage.cache_write_tokens if usage.cache_write_tokens
    end
    call_cost = cost
    values["cost"] = call_cost if call_cost
    values
  end
end
