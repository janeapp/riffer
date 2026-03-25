# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::StreamEvents::GuardrailTripwire < Riffer::StreamEvents::Base
  attr_reader :tripwire #: Riffer::Guardrails::Tripwire

  #: (Riffer::Guardrails::Tripwire, ?role: Symbol) -> void
  def initialize(tripwire, role: :assistant)
    super(role: role)
    @tripwire = tripwire
  end

  #: () -> String
  def reason
    tripwire.reason
  end

  #: () -> Symbol
  def phase
    tripwire.phase
  end

  #: () -> singleton(Riffer::Guardrail)
  def guardrail
    tripwire.guardrail
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    {
      role: @role,
      tripwire: tripwire.to_h
    }
  end
end
