# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::System < Riffer::Messages::Base
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::System)) -> Riffer::Messages::System
  def self.from_hash(msg)
    return msg if msg.is_a?(Riffer::Messages::System)

    new(msg[:content], id: msg[:id])
  end

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
