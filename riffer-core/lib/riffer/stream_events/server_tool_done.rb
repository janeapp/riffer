# frozen_string_literal: true
# rbs_inline: enabled

# Carries a server tool block for replay. WebSearchStatus and WebSearchDone are the events to
# display.
class Riffer::StreamEvents::ServerToolDone < Riffer::StreamEvents::Base
  attr_reader :part #: Riffer::Messages::Assistant::ServerToolPart # @dynamic part

  #--
  #: (Riffer::Messages::Assistant::ServerToolPart, ?role: Symbol) -> void
  def initialize(part, role: :assistant)
    super(role: role)
    @part = part
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, part: part.to_h }
  end
end
