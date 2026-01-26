# frozen_string_literal: true

# Base class for all streaming events in the Riffer framework.
#
# Subclasses must implement the +to_h+ method.
class Riffer::StreamEvents::Base
  # The message role (typically :assistant).
  #
  # Returns Symbol.
  attr_reader :role

  # Creates a new stream event.
  #
  # role:: Symbol - the message role (defaults to :assistant)
  def initialize(role: :assistant)
    @role = role
  end

  # Converts the event to a hash.
  #
  # Raises NotImplementedError if not implemented by subclass.
  def to_h
    raise NotImplementedError, "Subclasses must implement #to_h"
  end
end
