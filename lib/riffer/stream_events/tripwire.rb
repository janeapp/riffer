# frozen_string_literal: true

# Represents a guardrail tripwire event during streaming.
#
# Emitted when a guardrail blocks execution during the streaming pipeline.
class Riffer::StreamEvents::Tripwire < Riffer::StreamEvents::Base
  # The tripwire containing block details.
  #
  # Returns Riffer::Guardrails::Tripwire.
  attr_reader :tripwire

  # Creates a new tripwire stream event.
  #
  # tripwire:: Riffer::Guardrails::Tripwire - the tripwire details
  # role:: Symbol - the message role (defaults to :assistant)
  def initialize(tripwire, role: :assistant)
    super(role: role)
    @tripwire = tripwire
  end

  # The reason for blocking.
  #
  # Returns String.
  def reason
    tripwire.reason
  end

  # The phase when blocking occurred.
  #
  # Returns Symbol.
  def phase
    tripwire.phase
  end

  # The guardrail identifier that triggered the block.
  #
  # Returns String.
  def guardrail_id
    tripwire.guardrail_id
  end

  # Converts the event to a hash.
  #
  # Returns Hash with tripwire details.
  def to_h
    {
      role: @role,
      tripwire: tripwire.to_h
    }
  end
end
