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
  attr_reader :parameters #: Array[Riffer::Param]

  #--
  #: () -> void
  def initialize
    @parameters = []
  end

  # Defines a required parameter.
  #
  #--
  #: (Symbol, Class, ?description: String?, ?enum: Array[untyped]?, ?of: Class?) ?{ () -> void } -> void
  def required(name, type, description: nil, enum: nil, of: nil, &block)
    nested = build_nested(type, of, &block)
    @parameters << Riffer::Param.new(
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
  #: (Symbol, Class, ?description: String?, ?enum: Array[untyped]?, ?default: untyped, ?of: Class?) ?{ () -> void } -> void
  def optional(name, type, description: nil, enum: nil, default: nil, of: nil, &block)
    nested = build_nested(type, of, &block)
    @parameters << Riffer::Param.new(
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

      value = validate_nested(param, value, errors)

      validated[param.name] = value
    end

    raise Riffer::ValidationError, errors.join("; ") if errors.any?

    validated
  end

  # Returns a JSON-safe hash representation of this Params collection.
  #
  # See Riffer::Param#to_h.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    {parameters: @parameters.map(&:to_h)}
  end

  # Builds a Params from a hash produced by +#to_h+.
  #
  # Accepts both symbol-keyed and string-keyed hashes (e.g. from
  # +JSON.parse+ without +symbolize_names: true+).
  #
  #--
  #: (Hash[untyped, untyped]) -> Riffer::Params
  def self.from_h(hash)
    hash = Riffer::Helpers::HashNormalizer.deep_symbolize_keys(hash)
    instance = new
    (hash[:parameters] || []).each do |param_hash|
      instance.parameters << Riffer::Param.from_h(param_hash)
    end
    instance
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
    properties = {}
    required_params = []

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
  #: (Class, Class?) ?{ () -> void } -> Riffer::Params?
  def build_nested(type, of, &block)
    if of && block
      raise Riffer::ArgumentError, "cannot use both of: and a block"
    end

    if of
      unless type == Array
        raise Riffer::ArgumentError, "of: can only be used with Array type, got #{type}"
      end
      unless Riffer::Param::PRIMITIVE_TYPES.include?(of)
        raise Riffer::ArgumentError,
          "of: must be a primitive type (#{Riffer::Param::PRIMITIVE_TYPES.map(&:name).join(", ")}), got #{of}"
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
  #: (Riffer::Param, untyped, Array[String]) -> untyped
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
  #: (Riffer::Param, Hash[Symbol, untyped], Array[String]) -> Hash[Symbol, untyped]
  def validate_nested_hash(param, value, errors)
    param.nested_params.validate(value)
  rescue Riffer::ValidationError => e
    e.message.split("; ").each do |msg|
      errors << "#{param.name}.#{msg}"
    end
    value
  end

  #--
  #: (Riffer::Param, Array[untyped], Array[String]) -> Array[untyped]
  def validate_nested_array_of_objects(param, value, errors)
    value.map.with_index do |item, i|
      unless item.is_a?(Hash)
        errors << "#{param.name}[#{i}] must be an object"
        next item
      end
      param.nested_params.validate(item)
    rescue Riffer::ValidationError => e
      e.message.split("; ").each do |msg|
        errors << "#{param.name}[#{i}].#{msg}"
      end
      item
    end
  end

  #--
  #: (Riffer::Param, Array[untyped], Array[String]) -> void
  def validate_typed_array(param, value, errors)
    type_name = Riffer::Param::TYPE_MAPPINGS[param.item_type]
    value.each_with_index do |item, i|
      valid = if param.item_type == Riffer::Boolean || param.item_type == TrueClass || param.item_type == FalseClass
        item == true || item == false
      else
        item.is_a?(param.item_type)
      end
      errors << "#{param.name}[#{i}] must be a #{type_name}" unless valid
    end
  end
end
