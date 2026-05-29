# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Tools::Toolable provides the shared class-level DSL for anything that can
# present as a tool to an LLM — tools today, and subagents/workflows in the
# future.
#
# Extend this module to make a class discoverable as a tool by LLM providers.
# Provides identifier, description, params, timeout, and JSON schema
# generation.
#
# Instance-level execution concerns (+call+, +call_with_validation+, etc.)
# are NOT part of Toolable — those belong on Riffer::Tool.
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
  DEFAULT_TIMEOUT = 10 #: Integer

  # Tracks all classes that extend Toolable.
  #
  #--
  #: (Module) -> void
  def self.extended(base)
    base.extend Riffer::Helpers::ClassNameConverter
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
    return @identifier || class_name_to_path(Module.instance_method(:name).bind_call(self)) if value.nil?
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

  # Returns the kind of toolable entity.
  #
  # Defaults to +:tool+. Extensible to +:agent+, +:workflow+, etc.
  #
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
