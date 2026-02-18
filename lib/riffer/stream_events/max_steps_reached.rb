# frozen_string_literal: true
# rbs_inline: enabled

# Represents a max steps reached event during streaming.
#
# Emitted when the agent loop stops because the max_steps limit was reached.
class Riffer::StreamEvents::MaxStepsReached < Riffer::StreamEvents::Base
  # Creates a new max steps reached stream event.
  #
  # +role+ - the message role (defaults to :assistant).
  #
  #: (?role: Symbol) -> void
  def initialize(role: :assistant)
    super
  end

  # Converts the event to a hash.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    {role: @role}
  end
end
