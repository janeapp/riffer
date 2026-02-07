# frozen_string_literal: true
# rbs_inline: enabled

# Represents an incremental text chunk during streaming.
#
# Emitted when the LLM produces text content incrementally.
class Riffer::StreamEvents::TextDelta < Riffer::StreamEvents::Base
  # The incremental text content.
  attr_reader :content #: String

  #: content: String -- the incremental text content
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
