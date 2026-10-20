# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Params
  attr_reader :parameters #: Array[Riffer::Params::Param] # @dynamic parameters

  #--
  #: () -> void
  def initialize
    @parameters = []
  end

  # The inverse of +to_json_schema(strict: false)+. Raises Riffer::ArgumentError
  # on features outside the Params-expressible subset of JSON Schema.
  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Params
  def self.from_json_schema(schema)
    params = new
    properties = schema[:properties] || {}
    required = (schema[:required] || []).map(&:to_s)

    properties.each do |name, property_schema|
      params.parameters << Riffer::Params::Param.from_json_schema(
        name.to_sym, property_schema, required: required.include?(name.to_s),
      )
    end

    params
  end

  #--
  #: (Symbol, singleton(Riffer::Params::AnyOf), ?description: String?) { (Riffer::Params::AnyOf) [self: Riffer::Params::AnyOf] -> void } -> void
  #: (Symbol, Module, ?description: String?, ?enum: Array[untyped]?, ?format: String?, ?of: (Module | Array[untyped])?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def required(name, type, description: nil, enum: nil, format: nil, of: nil, &)
    item_type, dimensions = unwrap_of(of)
    nested = build_nested(type, item_type, enum, &) unless type == Riffer::Params::AnyOf
    variants = build_variants(of, enum, &) if type == Riffer::Params::AnyOf
    @parameters << Riffer::Params::Param.new(
      name: name,
      type: type,
      required: true,
      description: description,
      enum: enum,
      format: format,
      item_type: item_type,
      dimensions: dimensions,
      nested_params: nested,
      variants: variants,
    )
  end

  #--
  #: (Symbol, singleton(Riffer::Params::AnyOf), ?description: String?, ?default: untyped) { (Riffer::Params::AnyOf) [self: Riffer::Params::AnyOf] -> void } -> void
  #: (Symbol, Module, ?description: String?, ?enum: Array[untyped]?, ?format: String?, ?default: untyped, ?of: (Module | Array[untyped])?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def optional(name, type, description: nil, enum: nil, format: nil, default: nil, of: nil, &)
    item_type, dimensions = unwrap_of(of)
    nested = build_nested(type, item_type, enum, &) unless type == Riffer::Params::AnyOf
    variants = build_variants(of, enum, &) if type == Riffer::Params::AnyOf
    @parameters << Riffer::Params::Param.new(
      name: name,
      type: type,
      required: false,
      description: description,
      enum: enum,
      format: format,
      default: default,
      item_type: item_type,
      dimensions: dimensions,
      nested_params: nested,
      variants: variants,
    )
  end

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

      # A typed array's enum and format constrain its items, which validate_typed_array checks.
      if param.enum && !param.item_type && !param.enum.include?(value)
        errors << "#{param.name} must be one of: #{param.enum.join(', ')}"
        next
      end

      if param.format && !param.item_type && !Riffer::Params::Format.valid?(param.format, value)
        errors << "#{param.name} must be a valid #{param.format}"
        next
      end

      value = validate_nested(param, value, errors)

      validated[param.name] = coerce_value(param.type, value)
    end

    raise Riffer::ValidationError, errors.join("; ") if errors.any?

    validated
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    properties = {} #: Hash[String, untyped]
    required_params = [] #: Array[String]

    @parameters.each do |param|
      properties[param.name.to_s] = param.to_json_schema(strict: strict)
      # Providers enforcing strict structured output require every property in
      # +required+; strict mode makes optional ones nullable instead.
      required_params << param.name.to_s if strict || param.required
    end

    {
      type: "object",
      properties: properties,
      required: required_params,
      additionalProperties: false,
    }
  end

  private

  # Without this, +dup+ shares parameters, so defining one on either copy
  # would reach the other.
  #--
  #: (Riffer::Params) -> void
  def initialize_copy(source)
    super
    @parameters = source.parameters.map(&:dup)
  end

  #--
  #: ((Module | Array[untyped])?, ?Integer) -> [Module?, Integer]
  def unwrap_of(of, dimensions = 1)
    return [of, dimensions] unless of.is_a?(Array)
    raise Riffer::ArgumentError, "of: must nest exactly one type, got #{of.inspect}" unless of.size == 1 && of.first

    unwrap_of(of.first, dimensions + 1)
  end

  #--
  #: (Module, Module?, Array[untyped]?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def build_nested(type, of, enum, &block)
    raise Riffer::ArgumentError, "cannot use both of: and a block" if of && block
    raise Riffer::ArgumentError, "enum: cannot be used with Hash" if enum && type == Hash
    raise Riffer::ArgumentError, "enum: with Array requires of:" if enum && type == Array && !of

    if of
      raise Riffer::ArgumentError, "of: can only be used with Array type, got #{type}" unless type == Array

      unless Riffer::Params::Param::PRIMITIVE_TYPES.include?(of)
        primitives = Riffer::Params::Param::PRIMITIVE_TYPES.map(&:name).join(", ")
        raise Riffer::ArgumentError, "of: must be a primitive type (#{primitives}), got #{of}"
      end
      return nil
    end

    return unless block
    unless [Hash, Array].include?(type)
      raise Riffer::ArgumentError, "block can only be used with Hash or Array type, got #{type}"
    end

    nested = Riffer::Params.new
    nested.instance_eval(&block)
    nested
  end

  #--
  #: ((Module | Array[untyped])?, Array[untyped]?) ?{ (Riffer::Params::AnyOf) [self: Riffer::Params::AnyOf] -> void } -> Array[Riffer::Params]
  def build_variants(of, enum, &block)
    raise Riffer::ArgumentError, "of: cannot be used with AnyOf" if of
    raise Riffer::ArgumentError, "enum: cannot be used with AnyOf" if enum
    raise Riffer::ArgumentError, "AnyOf requires a block defining its variants" unless block

    any_of = Riffer::Params::AnyOf.new
    any_of.instance_eval(&block)
    raise Riffer::ArgumentError, "AnyOf requires at least two variants" if any_of.variants.size < 2

    any_of.variants
  end

  #--
  #: (Riffer::Params::Param, untyped, Array[String]) -> untyped
  def validate_nested(param, value, errors)
    if param.type == Riffer::Params::AnyOf
      validate_any_of(param, value, errors)
    elsif param.type == Hash && param.nested_params
      validate_nested_hash(param, value, errors)
    elsif param.type == Array && param.nested_params
      validate_nested_array_of_objects(param, value, errors)
    elsif param.type == Array && param.item_type
      validate_typed_array(param, value, errors)
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
  #: (Riffer::Params::Param, Hash[Symbol, untyped], Array[String]) -> Hash[Symbol, untyped]
  def validate_any_of(param, value, errors)
    variants = param.variants
    return value unless variants

    variant_errors = [] #: Array[String]
    variants.each.with_index(1) do |variant, number|
      validated = variant.validate(value)
      # Each variant's schema sets additionalProperties: false on every object
      # it declares, so a key outside this variant rules it out.
      unknown = undeclared_keys(value, validated)
      return validated if unknown.empty?

      variant_errors << "variant #{number} (#{unknown.map { |path| "#{path} is not allowed" }.join(', ')})"
    rescue Riffer::ValidationError => e
      # Enclosing params split errors on "; " to prefix their path, so one
      # variant's errors must not contain it.
      variant_errors << "variant #{number} (#{e.message.gsub('; ', ', ')})"
    end

    errors << "#{param.name} must match one of the variants: #{variant_errors.join(', ')}"
    value
  end

  # Validation drops keys a Params doesn't declare, at any depth, so they are
  # the keys in the input that are missing from the output.
  #--
  #: (untyped, untyped, ?String?) -> Array[String]
  def undeclared_keys(value, validated, path = nil)
    case value
    when Hash
      value.flat_map do |key, child|
        key_path = [path, key].compact.join(".")
        validated.key?(key) ? undeclared_keys(child, validated[key], key_path) : [key_path]
      end
    when Array
      value.each_with_index.flat_map { |item, i| undeclared_keys(item, validated[i], "#{path}[#{i}]") }
    else
      []
    end
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
  #: (Riffer::Params::Param, Array[untyped], Array[String], ?String, ?Integer) -> Array[untyped]
  def validate_typed_array(param, value, errors, path = param.name.to_s, dimensions = param.dimensions)
    item_type = param.item_type
    return value unless item_type

    value.map.with_index do |item, i|
      item_path = "#{path}[#{i}]"

      if dimensions > 1
        next validate_typed_array(param, item, errors, item_path, dimensions - 1) if item.is_a?(Array)

        errors << "#{item_path} must be an array"
        next item
      end

      unless valid_item?(item_type, item)
        errors << "#{item_path} must be a #{Riffer::Params::Param::TYPE_MAPPINGS[item_type]}"
        next item
      end

      if param.enum && !param.enum.include?(item)
        errors << "#{item_path} must be one of: #{param.enum.join(', ')}"
        next item
      end

      if param.format && !Riffer::Params::Format.valid?(param.format, item)
        errors << "#{item_path} must be a valid #{param.format}"
        next item
      end

      coerce_value(item_type, item)
    end
  end

  #--
  #: (Module, untyped) -> bool
  def valid_item?(type, item)
    if [Riffer::Params::Boolean, TrueClass, FalseClass].include?(type)
      [true, false].include?(item)
    elsif type == Float
      item.is_a?(Numeric)
    else
      item.is_a?(type)
    end
  end

  #--
  #: (Module, untyped) -> untyped
  def coerce_value(type, value)
    # JSON Schema "number" accepts integers; callers shouldn't get a type that
    # depends on whether the model wrote a decimal point.
    return value.to_f if type == Float

    value
  end
end
