# frozen_string_literal: true

# Riffer::Tools::Param represents a single parameter definition for a tool.
#
# Handles type validation and JSON Schema generation for individual parameters.
class Riffer::Tools::Param
  # Maps Ruby types to JSON Schema type strings
  TYPE_MAPPINGS = {
    String => "string",
    Integer => "integer",
    Float => "number",
    TrueClass => "boolean",
    FalseClass => "boolean",
    Array => "array",
    Hash => "object"
  }.freeze

  attr_reader :name, :type, :required, :description, :enum, :default

  # Creates a new parameter definition.
  #
  # name:: Symbol - the parameter name
  # type:: Class - the expected Ruby type
  # required:: Boolean - whether the parameter is required
  # description:: String or nil - optional description for the parameter
  # enum:: Array or nil - optional list of allowed values
  # default:: Object or nil - optional default value for optional parameters
  def initialize(name:, type:, required:, description: nil, enum: nil, default: nil)
    @name = name.to_sym
    @type = type
    @required = required
    @description = description
    @enum = enum
    @default = default
  end

  # Validates that a value matches the expected type.
  #
  # value:: Object - the value to validate
  #
  # Returns Boolean - true if valid, false otherwise.
  def valid_type?(value)
    return true if value.nil? && !required

    if type == TrueClass || type == FalseClass
      value == true || value == false
    else
      value.is_a?(type)
    end
  end

  # Returns the JSON Schema type name for this parameter.
  #
  # Returns String - the JSON Schema type.
  def type_name
    TYPE_MAPPINGS[type] || type.to_s.downcase
  end

  # Converts this parameter to JSON Schema format.
  #
  # Returns Hash - the JSON Schema representation.
  def to_json_schema
    schema = {type: type_name}
    schema[:description] = description if description
    schema[:enum] = enum if enum
    schema
  end
end
