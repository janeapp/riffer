# frozen_string_literal: true

# Represents an incremental reasoning chunk during streaming.
#
# Emitted when the LLM produces reasoning/thinking content incrementally.
# Only available with providers that support reasoning (e.g., OpenAI with reasoning option).
class Riffer::StreamEvents::ReasoningDelta < Riffer::StreamEvents::Base
  # The incremental reasoning content.
  #
  # Returns String.
  attr_reader :content

  # Creates a new reasoning delta event.
  #
  # content:: String - the incremental reasoning content
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
