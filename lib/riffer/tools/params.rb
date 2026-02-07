# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Tools::Params provides a DSL for defining tool parameters.
#
# Used within a Tool's +params+ block to define required and optional parameters.
#
#   params do
#     required :city, String, description: "The city name"
#     optional :units, String, default: "celsius", enum: ["celsius", "fahrenheit"]
#   end
#
class Riffer::Tools::Params
  attr_reader :parameters #: Array[Riffer::Tools::Param]

  #: return: void
  def initialize
    @parameters = []
  end

  # Defines a required parameter.
  #
  #: name: Symbol -- the parameter name
  #: type: Class -- the expected Ruby type
  #: description: String? -- optional description
  #: enum: Array[untyped]? -- optional list of allowed values
  #: return: void
  def required(name, type, description: nil, enum: nil)
    @parameters << Riffer::Tools::Param.new(
      name: name,
      type: type,
      required: true,
      description: description,
      enum: enum
    )
  end

  # Defines an optional parameter.
  #
  #: name: Symbol -- the parameter name
  #: type: Class -- the expected Ruby type
  #: description: String? -- optional description
  #: enum: Array[untyped]? -- optional list of allowed values
  #: default: untyped -- default value when not provided
  #: return: void
  def optional(name, type, description: nil, enum: nil, default: nil)
    @parameters << Riffer::Tools::Param.new(
      name: name,
      type: type,
      required: false,
      description: description,
      enum: enum,
      default: default
    )
  end

  # Validates arguments against parameter definitions.
  #
  # Raises Riffer::ValidationError if validation fails.
  #
  #: arguments: Hash[Symbol, untyped]
  #: return: Hash[Symbol, untyped]
  def validate(arguments)
    validated = {}
    errors = []

    @parameters.each do |param|
      value = arguments[param.name]

      if value.nil? && param.required
        errors << "#{param.name} is required"
        next
      end

      if value.nil?
        validated[param.name] = param.default
        next
      end

      unless param.valid_type?(value)
        errors << "#{param.name} must be a #{param.type_name}"
        next
      end

      if param.enum && !param.enum.include?(value)
        errors << "#{param.name} must be one of: #{param.enum.join(", ")}"
        next
      end

      validated[param.name] = value
    end

    raise Riffer::ValidationError, errors.join("; ") if errors.any?

    validated
  end

  # Converts all parameters to JSON Schema format.
  #
  #: return: Hash[Symbol, untyped]
  def to_json_schema
    properties = {}
    required_params = []

    @parameters.each do |param|
      properties[param.name.to_s] = param.to_json_schema
      required_params << param.name.to_s if param.required
    end

    {
      type: "object",
      properties: properties,
      required: required_params,
      additionalProperties: false
    }
  end
end
