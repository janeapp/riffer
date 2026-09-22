# frozen_string_literal: true
# rbs_inline: enabled

# Represents completed reasoning during streaming; only emitted by providers
# that support reasoning (e.g. OpenAI with the reasoning option).
class Riffer::StreamEvents::ReasoningDone < Riffer::StreamEvents::Base
  # The complete reasoning content.
  attr_reader :content #: String # @dynamic content

  # The structured reasoning block behind +content+, for adapters that produce
  # replayable parts; nil for those that only report reasoning text.
  attr_reader :part #: Riffer::Messages::Assistant::ReasoningPart? # @dynamic part

  #--
  #: (String, ?part: Riffer::Messages::Assistant::ReasoningPart?, ?role: Symbol) -> void
  def initialize(content, part: nil, role: :assistant)
    super(role: role)
    @content = content
    @part = part
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { role: @role, content: @content } #: Hash[Symbol, untyped]
    hash[:part] = part.to_h if part
    hash
  end
end
