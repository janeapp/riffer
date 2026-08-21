# frozen_string_literal: true
# rbs_inline: enabled

# Represents completed text generation during streaming.
class Riffer::StreamEvents::TextDone < Riffer::StreamEvents::Base
  # The complete text content.
  attr_reader :content #: String

  #--
  #: (String, ?role: Symbol) -> void
  def initialize(content, role: :assistant)
    super(role: role)
    @content = content
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, content: @content }
  end
end
