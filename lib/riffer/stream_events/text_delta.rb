# frozen_string_literal: true

# Represents an incremental text chunk during streaming.
#
# Emitted when the LLM produces text content incrementally.
class Riffer::StreamEvents::TextDelta < Riffer::StreamEvents::Base
  # The incremental text content.
  #
  # Returns String.
  attr_reader :content

  # Creates a new text delta event.
  #
  # content:: String - the incremental text content
  # role:: String - the message role (defaults to "assistant")
  def initialize(content, role: "assistant")
    super(role: role)
    @content = content
  end

  # Converts the event to a hash.
  #
  # Returns Hash with +:role+ and +:content+ keys.
  def to_h
    {role: @role, content: @content}
  end
end
