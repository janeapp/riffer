# frozen_string_literal: true

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
  #
  # Returns Riffer::TokenUsage.
  attr_reader :token_usage

  # Creates a new token usage done event.
  #
  # token_usage:: Riffer::TokenUsage - the token usage data
  # role:: Symbol - the message role (defaults to :assistant)
  def initialize(token_usage:, role: :assistant)
    super(role: role)
    @token_usage = token_usage
  end

  # Converts the event to a hash.
  #
  # Returns Hash with +:role+ and +:token_usage+ keys.
  def to_h
    {role: @role, token_usage: @token_usage.to_h}
  end
end
