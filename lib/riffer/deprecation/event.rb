# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Deprecation::Event
  attr_reader :id #: Symbol # @dynamic id

  attr_reader :message #: String # @dynamic message

  attr_reader :location #: String? # @dynamic location

  #--
  #: (id: Symbol, message: String, location: String?) -> void
  def initialize(id:, message:, location:)
    @id = id
    @message = message
    @location = location
  end

  #--
  #: () -> String
  def to_s
    text = "riffer: #{message}"
    location ? "#{text} Called from #{location}." : text
  end
end
