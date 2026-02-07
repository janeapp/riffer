# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all streaming events in the Riffer framework.
#
# Subclasses must implement the +to_h+ method.
class Riffer::StreamEvents::Base
  # The message role (typically :assistant).
  attr_reader :role #: Symbol

  #: role: Symbol -- the message role (defaults to :assistant)
  #: return: void
  def initialize(role: :assistant)
    @role = role
  end

  # Converts the event to a hash.
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #: return: Hash[Symbol, untyped]
  def to_h
    raise NotImplementedError, "Subclasses must implement #to_h"
  end
end
