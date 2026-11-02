# frozen_string_literal: true
# rbs_inline: enabled

# A call or result of a tool the provider ran itself (e.g. web search). Stored and replayed
# verbatim under the same rule as reasoning parts: only the adapter whose +format+ it is sends
# it back.
class Riffer::Messages::Assistant::ServerToolPart
  KINDS = %i[call result].freeze #: Array[Symbol]

  attr_reader :name #: String # @dynamic name
  attr_reader :kind #: Symbol # @dynamic kind

  # The provider's block, JSON-encoded and unchanged.
  attr_reader :data #: String # @dynamic data

  # Shared by a call and its result.
  attr_reader :id #: String? # @dynamic id

  attr_reader :format #: String? # @dynamic format

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::Assistant::ServerToolPart)) -> Riffer::Messages::Assistant::ServerToolPart
  def self.from_hash(part)
    return part if part.is_a?(Riffer::Messages::Assistant::ServerToolPart)

    new(
      name: part[:name],
      kind: part[:kind].to_sym,
      data: part[:data],
      id: part[:id],
      format: part[:format],
    )
  end

  #--
  #: (name: String, kind: Symbol, data: String, ?id: String?, ?format: String?) -> void
  def initialize(name:, kind:, data:, id: nil, format: nil)
    unless KINDS.include?(kind)
      raise Riffer::ArgumentError,
            "kind must be one of #{KINDS.inspect}, got #{kind.inspect}"
    end

    @name = name
    @kind = kind
    @data = data
    @id = id
    @format = format
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    { name: name, kind: kind, data: data, id: id, format: format }.compact
  end

  #--
  #: (untyped) -> bool
  def ==(other)
    other.is_a?(Riffer::Messages::Assistant::ServerToolPart) && to_h == other.to_h
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
