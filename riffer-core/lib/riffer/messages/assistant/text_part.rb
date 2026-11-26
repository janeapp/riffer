# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Messages::Assistant::TextPart
  attr_reader :text #: String # @dynamic text

  # The provider's whole block as JSON, kept when it carries more than the text (e.g. Anthropic
  # +citations+), so the adapter that produced it can send it back unchanged.
  attr_reader :data #: String? # @dynamic data

  attr_reader :format #: String? # @dynamic format

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant::TextPart)) -> Riffer::Messages::Assistant::TextPart
  def self.from_hash(part)
    return part if part.is_a?(Riffer::Messages::Assistant::TextPart)

    new(part[:text].to_s, data: part[:data], format: part[:format])
  end

  #--
  #: (String, ?data: String?, ?format: String?) -> void
  def initialize(text, data: nil, format: nil)
    @text = text
    @data = data
    @format = format
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { text: text, data: data, format: format }.compact
  end

  #--
  #: (untyped) -> bool
  def ==(other)
    other.is_a?(Riffer::Messages::Assistant::TextPart) && to_h == other.to_h
  end

  #--
  #: (untyped) -> bool
  def eql?(other)
    self == other
  end

  #--
  #: () -> Integer
  def hash
    to_h.hash
  end
end
