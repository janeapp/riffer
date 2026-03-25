# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::Base
  attr_reader :content #: String

  #: (String) -> void
  def initialize(content)
    @content = content
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: role, content: content}
  end

  #: () -> Symbol
  def role
    raise NotImplementedError, "Subclasses must implement #role"
  end
end
