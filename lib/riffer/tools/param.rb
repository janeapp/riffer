# frozen_string_literal: true
# rbs_inline: enabled

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
  }.freeze #: Hash[Class, String]

  attr_reader :name #: Symbol
  attr_reader :type #: Class
  attr_reader :required #: bool
  attr_reader :description #: String?
  attr_reader :enum #: Array[untyped]?
  attr_reader :default #: untyped

  #: name: Symbol -- the parameter name
  #: type: Class -- the expected Ruby type
  #: required: bool -- whether the parameter is required
  #: description: String? -- optional description for the parameter
  #: enum: Array[untyped]? -- optional list of allowed values
  #: default: untyped -- optional default value for optional parameters
  #: return: void
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
  #: value: untyped
  #: return: bool
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
  #: return: String
  def type_name
    TYPE_MAPPINGS[type] || type.to_s.downcase
  end

  # Converts this parameter to JSON Schema format.
  #
  #: return: Hash[Symbol, untyped]
  def to_json_schema
    schema = {type: type_name}
    schema[:description] = description if description
    schema[:enum] = enum if enum
    schema
  end
end
