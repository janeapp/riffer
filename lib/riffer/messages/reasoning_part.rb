# frozen_string_literal: true
# rbs_inline: enabled

# Represents one block of model reasoning attached to an assistant message.
# riffer stores and replays a part verbatim rather than interpreting it, so a
# provider that requires its own thinking blocks back gets them unchanged.
class Riffer::Messages::ReasoningPart
  TYPES = %i[text summary encrypted].freeze #: Array[Symbol]

  # What the part carries: readable reasoning (+:text+), a provider-condensed
  # digest (+:summary+), or an opaque payload (+:encrypted+).
  attr_reader :type #: Symbol # @dynamic type

  # The reasoning prose, for +:text+ and +:summary+ parts.
  attr_reader :text #: String? # @dynamic text

  # The opaque payload, for +:encrypted+ parts.
  attr_reader :data #: String? # @dynamic data

  # The provider's signature over the part, when it issues one.
  attr_reader :signature #: String? # @dynamic signature

  # The provider's identifier for the part, when it issues one.
  attr_reader :id #: String? # @dynamic id

  # The wire format of the part, owned by the provider adapter that produced it
  # (e.g. <tt>"anthropic-claude-v1"</tt>). Adapters replay only the formats they
  # recognize, so it is never validated here.
  attr_reader :format #: String? # @dynamic format

  # Builds a ReasoningPart from a hash, or returns +part+ unchanged when it is
  # already a ReasoningPart.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::ReasoningPart)) -> Riffer::Messages::ReasoningPart
  def self.from_hash(part)
    return part if part.is_a?(Riffer::Messages::ReasoningPart)

    new(
      type: part[:type].to_sym,
      text: part[:text],
      data: part[:data],
      signature: part[:signature],
      id: part[:id],
      format: part[:format],
    )
  end

  # Raises Riffer::ArgumentError on a +type+ outside TYPES.
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

  # Serializes the part to a hash, omitting the fields it doesn't carry.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { type: type, text: text, data: data, signature: signature, id: id, format: format }.compact
  end

  #--
  #: (untyped) -> bool
  def ==(other)
    other.is_a?(Riffer::Messages::ReasoningPart) && to_h == other.to_h
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
