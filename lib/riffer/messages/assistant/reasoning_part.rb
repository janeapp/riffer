# frozen_string_literal: true
# rbs_inline: enabled

# Stored and replayed verbatim, never interpreted, so a provider that requires its own thinking
# blocks back gets them unchanged.
class Riffer::Messages::Assistant::ReasoningPart
  TYPES = %i[text summary encrypted].freeze #: Array[Symbol]

  attr_reader :type #: Symbol # @dynamic type
  attr_reader :text #: String? # @dynamic text
  attr_reader :data #: String? # @dynamic data
  attr_reader :signature #: String? # @dynamic signature
  attr_reader :id #: String? # @dynamic id

  # Owned by the producing adapter (e.g. <tt>"anthropic-claude-v1"</tt>); adapters replay only the
  # formats they recognize, so it is never validated here.
  attr_reader :format #: String? # @dynamic format

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant::ReasoningPart)) -> Riffer::Messages::Assistant::ReasoningPart
  def self.from_hash(part)
    return part if part.is_a?(Riffer::Messages::Assistant::ReasoningPart)

    new(
      type: part[:type].to_sym,
      text: part[:text],
      data: part[:data],
      signature: part[:signature],
      id: part[:id],
      format: part[:format],
    )
  end

  #--
  #: (type: Symbol, ?text: String?, ?data: String?, ?signature: String?, ?id: String?, ?format: String?) -> void
  def initialize(type:, text: nil, data: nil, signature: nil, id: nil, format: nil)
    unless TYPES.include?(type)
      raise Riffer::ArgumentError,
            "type must be one of #{TYPES.inspect}, got #{type.inspect}"
    end

    @type = type
    @text = text
    @data = data
    @signature = signature
    @id = id
    @format = format
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { type: type, text: text, data: data, signature: signature, id: id, format: format }.compact
  end

  #--
  #: (untyped) -> bool
  def ==(other)
    other.is_a?(Riffer::Messages::Assistant::ReasoningPart) && to_h == other.to_h
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
