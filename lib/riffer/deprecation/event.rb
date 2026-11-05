# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Deprecation::Event
  attr_reader :id #: Symbol # @dynamic id

  attr_reader :message #: String # @dynamic message

  attr_reader :removed_in #: String # @dynamic removed_in

  attr_reader :location #: String? # @dynamic location

  #--
  #: (id: Symbol, message: String, removed_in: String, location: String?) -> void
  def initialize(id:, message:, removed_in:, location:)
    @id = id
    @message = message
    @removed_in = removed_in
    @location = location
  end

  #--
  #: () -> String
  def to_s
    text = "riffer: #{message} It will be removed in riffer #{removed_in}."
    location ? "#{text} Called from #{location}." : text
  end
end
