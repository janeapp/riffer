# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all streaming events. Subclasses must implement +to_h+.
class Riffer::StreamEvents::Base
  # The message role (typically :assistant).
  attr_reader :role #: Symbol

  #--
  #: (?role: Symbol) -> void
  def initialize(role: :assistant)
    @role = role
  end

  # Converts the event to a hash.
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    raise NotImplementedError, "Subclasses must implement #to_h"
  end
end
