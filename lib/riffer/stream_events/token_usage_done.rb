# frozen_string_literal: true
# rbs_inline: enabled

# Represents completion of token usage tracking during streaming.
#
# Emitted when the LLM has finished and token usage data is available.
#
#   event.token_usage.input_tokens   # => 100
#   event.token_usage.output_tokens  # => 50
#   event.token_usage.total_tokens   # => 150
#
class Riffer::StreamEvents::TokenUsageDone < Riffer::StreamEvents::Base
  # The token usage data for this response.
  attr_reader :token_usage #: Riffer::TokenUsage

  #: (token_usage: Riffer::TokenUsage, ?role: Symbol) -> void
  def initialize(token_usage:, role: :assistant)
    super(role: role)
    @token_usage = token_usage
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, token_usage: @token_usage.to_h}
  end
end
