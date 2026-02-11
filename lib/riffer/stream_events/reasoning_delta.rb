# frozen_string_literal: true
# rbs_inline: enabled

# Represents an incremental reasoning chunk during streaming.
#
# Emitted when the LLM produces reasoning/thinking content incrementally.
# Only available with providers that support reasoning (e.g., OpenAI with reasoning option).
class Riffer::StreamEvents::ReasoningDelta < Riffer::StreamEvents::Base
  # The incremental reasoning content.
  attr_reader :content #: String

  #: (String, ?role: Symbol) -> void
  def initialize(content, role: :assistant)
    super(role: role)
    @content = content
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, content: @content}
  end
end
