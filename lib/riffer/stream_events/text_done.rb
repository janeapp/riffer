# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::TextDone < Riffer::StreamEvents::Base
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
