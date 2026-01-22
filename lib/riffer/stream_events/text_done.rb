# frozen_string_literal: true

# Represents completion of text generation during streaming.
#
# Emitted when the LLM has finished producing text content.
class Riffer::StreamEvents::TextDone < Riffer::StreamEvents::Base
  # The complete text content.
  #
  # Returns String.
  attr_reader :content

  # Creates a new text done event.
  #
  # content:: String - the complete text content
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
