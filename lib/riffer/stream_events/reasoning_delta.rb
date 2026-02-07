# frozen_string_literal: true
# rbs_inline: enabled

# Represents an incremental reasoning chunk during streaming.
#
# Emitted when the LLM produces reasoning/thinking content incrementally.
# Only available with providers that support reasoning (e.g., OpenAI with reasoning option).
class Riffer::StreamEvents::ReasoningDelta < Riffer::StreamEvents::Base
  # The incremental reasoning content.
  attr_reader :content #: String

  #: content: String -- the incremental reasoning content
  #: role: Symbol -- the message role (defaults to :assistant)
  #: return: void
  def initialize(content, role: :assistant)
    super(role: role)
    @content = content
  end

  #: return: Hash[Symbol, untyped]
  def to_h
    {role: @role, content: @content}
  end
end
