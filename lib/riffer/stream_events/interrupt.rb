# frozen_string_literal: true
# rbs_inline: enabled

# Represents an interrupt event during streaming.
#
# Emitted when a callback interrupts the agent loop via +throw :riffer_interrupt+.
class Riffer::StreamEvents::Interrupt < Riffer::StreamEvents::Base
  # The reason provided with the interrupt, if any.
  attr_reader :reason #: (String | Symbol)?

  #: (?reason: (String | Symbol)?) -> void
  def initialize(reason: nil)
    super(role: :system)
    @reason = reason
  end

  # Converts the event to a hash.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    h = {role: @role, interrupt: true}
    h[:reason] = @reason if @reason
    h
  end
end
