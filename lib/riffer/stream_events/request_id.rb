# frozen_string_literal: true
# rbs_inline: enabled

# Emitted at most once, with the first chunk that carries the id, so a stream
# that stalls afterwards can still be traced.
class Riffer::StreamEvents::RequestId < Riffer::StreamEvents::Base
  attr_reader :request_id #: String # @dynamic request_id

  #--
  #: (String, ?role: Symbol) -> void
  def initialize(request_id, role: :assistant)
    super(role: role)
    @request_id = request_id
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { role: @role, request_id: @request_id }
  end
end
