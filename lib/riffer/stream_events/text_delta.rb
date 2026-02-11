# frozen_string_literal: true
# rbs_inline: enabled

# Represents an incremental text chunk during streaming.
#
# Emitted when the LLM produces text content incrementally.
class Riffer::StreamEvents::TextDelta < Riffer::StreamEvents::Base
  # The incremental text content.
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
