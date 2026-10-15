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
  #: (Symbol, Module, ?description: String?, ?enum: Array[untyped]?, ?of: Module?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def required(name, type, description: nil, enum: nil, of: nil, &)
    nested = build_nested(type, of, &) unless type == Riffer::Params::AnyOf
    variants = build_variants(of, enum, &) if type == Riffer::Params::AnyOf
    @parameters << Riffer::Params::Param.new(
      name: name,
      type: type,
      required: true,
      description: description,
      enum: enum,
      item_type: of,
      nested_params: nested,
      variants: variants,
    )
  end

  #--
  #: (Symbol, singleton(Riffer::Params::AnyOf), ?description: String?, ?default: untyped) { (Riffer::Params::AnyOf) [self: Riffer::Params::AnyOf] -> void } -> void
  #: (Symbol, Module, ?description: String?, ?enum: Array[untyped]?, ?default: untyped, ?of: Module?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> void
  def optional(name, type, description: nil, enum: nil, default: nil, of: nil, &)
    nested = build_nested(type, of, &) unless type == Riffer::Params::AnyOf
    variants = build_variants(of, enum, &) if type == Riffer::Params::AnyOf
    @parameters << Riffer::Params::Param.new(
      name: name,
      type: type,
      required: false,
      description: description,
      enum: enum,
      default: default,
      item_type: of,
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

      if param.enum && !param.enum.include?(value)
        errors << "#{param.name} must be one of: #{param.enum.join(', ')}"
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
  #: (Module, Module?) ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
  def build_nested(type, of, &block)
    raise Riffer::ArgumentError, "cannot use both of: and a block" if of && block

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
  #: (Module?, Array[untyped]?) ?{ (Riffer::Params::AnyOf) [self: Riffer::Params::AnyOf] -> void } -> Array[Riffer::Params]
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
    if param.type == Riffer::Params::AnyOf && param.variants
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
      # Each variant is sent with additionalProperties: false, so a key only
      # another variant defines rules this one out.
      unknown = value.keys - validated.keys
      return validated if unknown.empty?

      variant_errors << "variant #{number} (#{unknown.map { |key| "#{key} is not allowed" }.join(', ')})"
    rescue Riffer::ValidationError => e
      # Enclosing params split errors on "; " to prefix their path, so one
      # variant's errors must not contain it.
      variant_errors << "variant #{number} (#{e.message.split('; ').join(', ')})"
    end

    errors << "#{param.name} must match one of the variants: #{variant_errors.join(', ')}"
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
  #: (Riffer::Params::Param, Array[untyped], Array[String]) -> Array[untyped]
  def validate_typed_array(param, value, errors)
    item_type = param.item_type
    return value unless item_type

    type_name = Riffer::Params::Param::TYPE_MAPPINGS[item_type]
    valid_item = if [Riffer::Params::Boolean, TrueClass, FalseClass].include?(item_type)
                   ->(item) { [true, false].include?(item) }
                 elsif item_type == Float
                   ->(item) { item.is_a?(Numeric) }
                 else
                   ->(item) { item.is_a?(item_type) }
                 end
    value.map.with_index do |item, i|
      unless valid_item.call(item)
        errors << "#{param.name}[#{i}] must be a #{type_name}"
        next item
      end

      coerce_value(item_type, item)
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
