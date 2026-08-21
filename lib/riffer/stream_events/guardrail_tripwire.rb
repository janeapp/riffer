# frozen_string_literal: true
# rbs_inline: enabled

# Emitted when a guardrail blocks execution during streaming.
class Riffer::StreamEvents::GuardrailTripwire < Riffer::StreamEvents::Base
  # The tripwire containing block details.
  attr_reader :tripwire #: Riffer::Guardrails::Tripwire

  #--
  #: (Riffer::Guardrails::Tripwire, ?role: Symbol) -> void
  def initialize(tripwire, role: :assistant)
    super(role: role)
    @tripwire = tripwire
  end

  # The reason for blocking.
  #
  #--
  #: () -> String
  def reason
    tripwire.reason
  end

  # The phase when blocking occurred (:before or :after).
  #
  #--
  #: () -> Symbol
  def phase
    tripwire.phase
  end

  # The guardrail class that triggered the block.
  #
  #--
  #: () -> singleton(Riffer::Guardrail)
  def guardrail
    tripwire.guardrail
  end

  # Converts the event to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      role: @role,
      tripwire: tripwire.to_h,
    }
  end
end
