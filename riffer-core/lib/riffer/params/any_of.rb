# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Params::AnyOf
  # @rbs @name: Symbol

  attr_reader :variants #: Array[Riffer::Params | Riffer::Params::Param] # @dynamic variants

  #--
  #: (Symbol) -> void
  def initialize(name)
    @name = name
    @variants = []
  end

  #--
  #: (?(Symbol | Module)?, ?description: String?, ?enum: Array[untyped]?, ?format: String?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def variant(type = nil, description: nil, enum: nil, format: nil, &block)
    if type
      raise Riffer::ArgumentError, "variant takes a type or a block, not both" if block

      @variants << primitive(type, description, enum, format)
    elsif block
      if description || enum || format
        raise Riffer::ArgumentError, "description:, enum: and format: only apply to a primitive variant"
      end

      params = Riffer::Params.new
      params.instance_eval(&block)
      @variants << params
    else
      raise Riffer::ArgumentError, "variant requires a type or a block defining its properties"
    end
  end

  private

  #--
  #: (Symbol | Module, String?, Array[untyped]?, String?) -> Riffer::Params::Param
  def primitive(type, description, enum, format)
    Riffer::Params::Param.new(
      name: @name, type: Riffer::Params::Param.resolve_type!(type, "variant type", Riffer::Params::Param::PRIMITIVE_TYPES),
      required: true,
      description: description, enum: enum, format: format,
    )
  end
end
