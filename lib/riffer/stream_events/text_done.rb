# frozen_string_literal: true
# rbs_inline: enabled

# Represents completion of text generation during streaming.
#
# Emitted when the LLM has finished producing text content.
class Riffer::StreamEvents::TextDone < Riffer::StreamEvents::Base
  # The complete text content.
  attr_reader :content #: String

  #: content: String -- the complete text content
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
