# frozen_string_literal: true

# Represents completion of usage tracking during streaming.
#
# Emitted when the LLM has finished and usage data is available.
#
#   event.usage.input_tokens   # => 100
#   event.usage.output_tokens  # => 50
#   event.usage.total_tokens   # => 150
#
class Riffer::StreamEvents::UsageDone < Riffer::StreamEvents::Base
  # The usage data for this response.
  #
  # Returns Riffer::Usage.
  attr_reader :usage

  # Creates a new usage done event.
  #
  # usage:: Riffer::Usage - the usage data
  # role:: Symbol - the message role (defaults to :assistant)
  def initialize(usage:, role: :assistant)
    super(role: role)
    @usage = usage
  end

  # Converts the event to a hash.
  #
  # Returns Hash with +:role+ and +:usage+ keys.
  def to_h
    {role: @role, usage: @usage.to_h}
  end
end
