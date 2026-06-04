# frozen_string_literal: true
# rbs_inline: enabled

# Represents a system message (instructions) in a conversation.
class Riffer::Messages::System < Riffer::Messages::Base
  #--
  #: () -> Symbol
  def role
    :system
  end

  #--
  #: (Riffer::Messages::System) -> Riffer::Messages::System
  def +(other)
    self.class.new("#{content}\n\n#{other.content}")
  end
end
