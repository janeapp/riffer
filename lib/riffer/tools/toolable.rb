# frozen_string_literal: true
# rbs_inline: enabled

# Shared class-level DSL for anything that presents as a tool to an LLM. Extend
# it to make a class discoverable as a tool; instance-level execution (+call+,
# +call_with_validation+) lives on Riffer::Tool instead.
#
#   class MyTool
#     extend Riffer::Tools::Toolable
#
#     description "Does something useful"
#
#     params do
#       required :input, String
#     end
#   end
#
module Riffer::Tools::Toolable
  # @rbs self.@extenders: Array[Module]?
  # @rbs @description: String?
  # @rbs @identifier: String?
  # @rbs @timeout: (Integer | Float)?
  # @rbs @params_builder: Riffer::Params?
  # @rbs @kind: Symbol?

  DEFAULT_TIMEOUT = 10 #: Integer

  # Tracks all classes that extend Toolable.
  #
  #--
  #: (Module) -> void
  def self.extended(base)
    extenders = (@extenders ||= []) #: Array[Module]
    extenders << base
  end

  # Returns all classes that have extended Toolable.
  #
  #--
  #: () -> Array[Module]
  def self.all
    @extenders || []
  end

  # Gets or sets the tool description.
  #
  #--
  #: (?String?) -> String?
  def description(value = nil)
    return @description if value.nil?
    @description = value.to_s
  end

  # Gets or sets the tool identifier/name.
  #
  #--
  #: (?String?) -> String
  def identifier(value = nil)
    return @identifier || Riffer::Helpers::ClassNameConverter.convert(Module.instance_method(:name).bind_call(self)) if value.nil?
    @identifier = value.to_s
  end

  # Alias for identifier — used by providers.
  #
  #--
  #: (?String?) -> String
  def name(value = nil)
    return identifier(value) unless value.nil?
    identifier
  end

  # Gets or sets the tool timeout in seconds.
  #
  #--
  #: (?(Integer | Float)?) -> (Integer | Float)
  def timeout(value = nil)
    return @timeout || DEFAULT_TIMEOUT if value.nil?
    @timeout = value.to_f
  end

  # Defines parameters using the Params DSL.
  #
  #--
  #: () ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def params(&block)
    return @params_builder if block.nil?
    builder = Riffer::Params.new
    builder.instance_eval(&block)
    @params_builder = builder
  end

  # Returns the JSON Schema for the tool's parameters.
  #
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def parameters_schema(strict: false)
    @params_builder&.to_json_schema(strict: strict) || empty_schema
  end

  # Returns the kind of toolable entity; defaults to +:tool+.
  #--
  #: (?Symbol?) -> Symbol
  def kind(value = nil)
    return @kind || :tool if value.nil?
    @kind = value.to_sym
  end

  # Returns a provider-agnostic tool schema hash.
  #
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_tool_schema(strict: false)
    {
      name: name,
      description: description,
      parameters_schema: parameters_schema(strict: strict)
    }
  end

  # Validates that the minimum required metadata is present for LLM tool use.
  #
  # Raises Riffer::ArgumentError if validation fails.
  #
  #--
  #: () -> true
  def validate_as_tool!
    raise Riffer::ArgumentError, "#{self} must define a description" if description.nil? || description.to_s.strip.empty?
    raise Riffer::ArgumentError, "#{self} must have an identifier" if identifier.nil? || identifier.to_s.strip.empty?
    true
  end

  private

  def empty_schema # :nodoc:
    properties = {} #: Hash[Symbol, untyped]
    required = [] #: Array[untyped]
    {type: "object", properties: properties, required: required, additionalProperties: false}
  end
end
