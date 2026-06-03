# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Params provides a DSL for defining parameters.
#
# Used within a Tool's +params+ block to define required and optional parameters,
# and by StructuredOutput to define response schemas.
#
#   params do
#     required :city, String, description: "The city name"
#     optional :units, String, default: "celsius", enum: ["celsius", "fahrenheit"]
#   end
#
class Riffer::Params
  attr_reader :parameters #: Array[Riffer::Params::Param]

  #--
  #: () -> void
  def initialize
    @parameters = []
  end

  # Reconstructs a Params from a JSON Schema object (the inverse of
  # +to_json_schema(strict: false)+).
  #
  # Accepts the Symbol-keyed object schema produced by +to_json_schema+
  # (property-name keys may be String or Symbol — both are normalized).
  # Reconstructs types, +required+, +description+, +enum+, +default+,
  # typed-array +item_type+, and nested object/array Params recursively.
  #
  # Round-trips losslessly with +to_json_schema(strict: false)+ over the
  # Params-expressible subset of JSON Schema. Raises Riffer::ArgumentError
  # on a schema using features outside that subset.
  #
  #   schema = params.to_json_schema(strict: false)
  #   Riffer::Params.from_json_schema(schema) # => equivalent Riffer::Params
  #
  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Params
  def self.from_json_schema(schema)
    params = new
    properties = schema[:properties] || {}
    required = (schema[:required] || []).map { |key| key.to_s }

    properties.each do |name, property_schema|
      params.parameters << Riffer::Params::Param.from_json_schema(
        name.to_sym, property_schema, required: required.include?(name.to_s)
      )
    end

    params
  end

  # Defines a required parameter.
  #
  #--
  #: (Symbol, Module, ?description: String?, ?enum: Array[untyped]?, ?of: Module?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def required(name, type, description: nil, enum: nil, of: nil, &block)
    nested = build_nested(type, of, &block)
    @parameters << Riffer::Params::Param.new(
      name: name,
      type: type,
      required: true,
      description: description,
      enum: enum,
      item_type: of,
      nested_params: nested
    )
  end

  # Defines an optional parameter.
  #
  #--
  #: (Symbol, Module, ?description: String?, ?enum: Array[untyped]?, ?default: untyped, ?of: Module?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def optional(name, type, description: nil, enum: nil, default: nil, of: nil, &block)
    nested = build_nested(type, of, &block)
    @parameters << Riffer::Params::Param.new(
      name: name,
      type: type,
      required: false,
      description: description,
      enum: enum,
      default: default,
      item_type: of,
      nested_params: nested
    )
  end

  # Validates arguments against parameter definitions.
  #
  # Raises Riffer::ValidationError if validation fails.
  #
  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def validate(arguments)
    validated = {} #: Hash[Symbol, untyped]
    errors = [] #: Array[String]

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

      value = validate_nested(param, value, errors)

      validated[param.name] = value
    end

    raise Riffer::ValidationError, errors.join("; ") if errors.any?

    validated
  end

  # Converts all parameters to JSON Schema format.
  #
  # When +strict+ is true, every property appears in +required+ and
  # optional properties are made nullable instead. This satisfies
  # providers that enforce strict structured output schemas.
  #
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    properties = {} #: Hash[String, untyped]
    required_params = [] #: Array[String]

    @parameters.each do |param|
      properties[param.name.to_s] = param.to_json_schema(strict: strict)
      required_params << param.name.to_s if strict || param.required
    end

    {
      type: "object",
      properties: properties,
      required: required_params,
      additionalProperties: false
    }
  end

  private

  #--
  #: (Module, Module?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def build_nested(type, of, &block)
    if of && block
      raise Riffer::ArgumentError, "cannot use both of: and a block"
    end

    if of
      unless type == Array
        raise Riffer::ArgumentError, "of: can only be used with Array type, got #{type}"
      end
      unless Riffer::Params::Param::PRIMITIVE_TYPES.include?(of)
        raise Riffer::ArgumentError,
          "of: must be a primitive type (#{Riffer::Params::Param::PRIMITIVE_TYPES.map(&:name).join(", ")}), got #{of}"
      end
      return nil
    end

    if block
      unless type == Hash || type == Array
        raise Riffer::ArgumentError, "block can only be used with Hash or Array type, got #{type}"
      end
      nested = Riffer::Params.new
      nested.instance_eval(&block)
      nested
    end
  end

  #--
  #: (Riffer::Params::Param, untyped, Array[String]) -> untyped
  def validate_nested(param, value, errors)
    if param.type == Hash && param.nested_params
      validate_nested_hash(param, value, errors)
    elsif param.type == Array && param.nested_params
      validate_nested_array_of_objects(param, value, errors)
    elsif param.type == Array && param.item_type
      validate_typed_array(param, value, errors)
      value
    else
      value
    end
  end

  #--
  #: (Riffer::Params::Param, Hash[Symbol, untyped], Array[String]) -> Hash[Symbol, untyped]
  def validate_nested_hash(param, value, errors)
    nested = param.nested_params
    return value unless nested
    nested.validate(value)
  rescue Riffer::ValidationError => e
    e.message.split("; ").each do |msg|
      errors << "#{param.name}.#{msg}"
    end
    value
  end

  #--
  #: (Riffer::Params::Param, Array[untyped], Array[String]) -> Array[untyped]
  def validate_nested_array_of_objects(param, value, errors)
    nested = param.nested_params
    return value unless nested
    value.map.with_index do |item, i|
      unless item.is_a?(Hash)
        errors << "#{param.name}[#{i}] must be an object"
        next item
      end
      nested.validate(item)
    rescue Riffer::ValidationError => e
      e.message.split("; ").each do |msg|
        errors << "#{param.name}[#{i}].#{msg}"
      end
      item
    end
  end

  #--
  #: (Riffer::Params::Param, Array[untyped], Array[String]) -> void
  def validate_typed_array(param, value, errors)
    item_type = param.item_type
    return unless item_type
    type_name = Riffer::Params::Param::TYPE_MAPPINGS[item_type]
    value.each_with_index do |item, i|
      valid = if item_type == Riffer::Params::Boolean || item_type == TrueClass || item_type == FalseClass
        item == true || item == false
      else
        item.is_a?(item_type)
      end
      errors << "#{param.name}[#{i}] must be a #{type_name}" unless valid
    end
  end
end
