# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::TokenUsageDone < Riffer::StreamEvents::Base
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
