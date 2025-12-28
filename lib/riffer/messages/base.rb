# frozen_string_literal: true

class Riffer::Messages::Base
  attr_reader :content

  def initialize(content)
    @content = content
  end

  def to_h
    {role: role, content: content}
  end

  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end
end
