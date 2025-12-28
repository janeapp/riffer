# frozen_string_literal: true

class Riffer::StreamEvents::TextDelta < Riffer::StreamEvents::Base
  attr_reader :content

  def initialize(content, role: "assistant")
    super(role: role)
    @content = content
  end

  def to_h
    {role: @role, content: @content}
  end
end
