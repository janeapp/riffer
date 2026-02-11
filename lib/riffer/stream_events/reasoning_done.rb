# frozen_string_literal: true
# rbs_inline: enabled

# Represents completion of reasoning during streaming.
#
# Emitted when the LLM has finished producing reasoning/thinking content.
# Only available with providers that support reasoning (e.g., OpenAI with reasoning option).
class Riffer::StreamEvents::ReasoningDone < Riffer::StreamEvents::Base
  # The complete reasoning content.
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
