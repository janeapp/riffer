# frozen_string_literal: true
# rbs_inline: enabled

# @rbs module-self Module
module Riffer::Tools::Toolable
  # @rbs self.@extenders: Array[Module]?
  # @rbs @description: String?
  # @rbs @identifier: String?
  # @rbs @timeout: (Integer | Float)?
  # @rbs @params_builder: Riffer::Params?
  # @rbs @kind: Symbol?

  DEFAULT_TIMEOUT = 10 #: Integer

  #--
  #: (Module) -> void
  def self.extended(base)
    extenders = (@extenders ||= []) #: Array[Module]
    extenders << base
  end

  #--
  #: () -> Array[Module]
  def self.all
    @extenders || []
  end

  #--
  #: (?String?) -> String?
  def description(value = nil)
    return @description if value.nil?

    @description = value.to_s
  end

  #--
  #: (?String?) -> String
  def identifier(value = nil)
    return @identifier || Riffer::Helpers::Identifier.for(self) if value.nil?

    @identifier = value.to_s
  end

  #--
  #: (?String?) -> String
  def name(value = nil)
    return identifier(value) if value

    identifier
  end

  #--
  #: (?(Integer | Float)?) -> (Integer | Float)
  def timeout(value = nil)
    return @timeout || DEFAULT_TIMEOUT if value.nil?

    @timeout = value.to_f
  end

  #--
  #: () ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def params(&block)
    return @params_builder if block.nil?

    builder = Riffer::Params.new
    builder.instance_eval(&block)
    @params_builder = builder
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def parameters_schema(strict: false)
    @params_builder&.to_json_schema(strict: strict) || empty_schema
  end

  #--
  #: (?Symbol?) -> Symbol
  def kind(value = nil)
    return @kind || :tool if value.nil?

    @kind = value.to_sym
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_tool_schema(strict: false)
    {
      name: name,
      description: description,
      parameters_schema: parameters_schema(strict: strict),
    }
  end

  #--
  #: () -> true
  def validate_as_tool!
    if description.nil? || description.to_s.strip.empty?
      raise Riffer::ArgumentError,
            "#{self} must define a description"
    end
    raise Riffer::ArgumentError, "#{self} must have an identifier" if identifier.nil? || identifier.to_s.strip.empty?

    true
  end

  private

  def empty_schema # :nodoc:
    properties = {} #: Hash[Symbol, untyped]
    required = [] #: Array[untyped]
    { type: "object", properties: properties, required: required, additionalProperties: false }
  end
end
