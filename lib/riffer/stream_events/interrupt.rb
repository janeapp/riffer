# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::Interrupt < Riffer::StreamEvents::Base
  attr_reader :reason #: (String | Symbol)?

  #: (?reason: (String | Symbol)?) -> void
  def initialize(reason: nil)
    super(role: :system)
    @reason = reason
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    h = {role: @role, interrupt: true}
    h[:reason] = @reason if @reason
    h
  end
end
