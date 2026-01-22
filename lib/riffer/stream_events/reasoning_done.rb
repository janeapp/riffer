# frozen_string_literal: true

# Represents completion of reasoning during streaming.
#
# Emitted when the LLM has finished producing reasoning/thinking content.
# Only available with providers that support reasoning (e.g., OpenAI with reasoning option).
class Riffer::StreamEvents::ReasoningDone < Riffer::StreamEvents::Base
  # The complete reasoning content.
  #
  # Returns String.
  attr_reader :content

  # Creates a new reasoning done event.
  #
  # content:: String - the complete reasoning content
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
