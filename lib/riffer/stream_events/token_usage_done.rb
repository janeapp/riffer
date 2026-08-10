# frozen_string_literal: true
# rbs_inline: enabled

# Final token usage for the response, emitted when the LLM finishes.
class Riffer::StreamEvents::TokenUsageDone < Riffer::StreamEvents::Base
  # The token usage data for this response.
  attr_reader :token_usage #: Riffer::Providers::TokenUsage

  #--
  #: (token_usage: Riffer::Providers::TokenUsage, ?role: Symbol) -> void
  def initialize(token_usage:, role: :assistant)
    super(role: role)
    @token_usage = token_usage
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, token_usage: @token_usage.to_h }
  end
end
