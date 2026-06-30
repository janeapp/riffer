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
  #: (provider: String, duration: Float, ?model: String?, ?token_usage: Riffer::Providers::TokenUsage?, ?finish_reason: Riffer::Providers::FinishReason?, ?error_type: String?, ?error: Exception?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(provider:, duration:, model: nil, token_usage: nil, finish_reason: nil, error_type: nil, error: nil, tags: {}, trace_id: nil, span_id: nil)
    super(duration: duration, error_type: error_type, error: error, tags: tags, trace_id: trace_id, span_id: span_id)
    @provider = provider
    @model = model
    @token_usage = token_usage
    @finish_reason = finish_reason
  end

  # The operation identifier.
  #--
  #: () -> Symbol
  def operation = :chat

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
end
