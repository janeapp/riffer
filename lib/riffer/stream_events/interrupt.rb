# frozen_string_literal: true
# rbs_inline: enabled

# Represents an interrupt event during streaming.
#
# Emitted when a callback interrupts the agent loop via +throw :riffer_interrupt+.
class Riffer::StreamEvents::Interrupt < Riffer::StreamEvents::Base
  #: () -> void
  def initialize
    super(role: :system)
  end

  # Converts the event to a hash.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role, interrupt: true}
  end
end
