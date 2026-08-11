# frozen_string_literal: true
# rbs_inline: enabled

# A single parameter definition, handling type validation and JSON Schema
# generation.
class Riffer::Params::Param
  # Maps Ruby types to JSON Schema type strings
  TYPE_MAPPINGS = {
    String => "string",
    Integer => "integer",
    Float => "number",
    Riffer::Params::Boolean => "boolean",
    TrueClass => "boolean",
    FalseClass => "boolean",
    Array => "array",
    Hash => "object",
  }.freeze #: Hash[Module, String]

  # Primitive types allowed for the <tt>of:</tt> keyword on Array params
  PRIMITIVE_TYPES = (TYPE_MAPPINGS.keys - [Array, Hash]).freeze #: Array[Module]

  # Maps JSON Schema type strings back to Ruby types (inverse of TYPE_MAPPINGS),
  # collapsing the three boolean spellings onto Riffer::Params::Boolean.
  JSON_TYPE_MAPPINGS = {
    "string" => String,
    "integer" => Integer,
    "number" => Float,
    "boolean" => Riffer::Params::Boolean,
    "array" => Array,
    "object" => Hash,
  }.freeze #: Hash[String, Module]

  # The parameter name.
  attr_reader :name #: Symbol

  # The Ruby type.
  attr_reader :type #: Module

  # Whether the parameter is required.
  attr_reader :required #: bool

  # The parameter description, if any.
  attr_reader :description #: String?

  # Allowed values, if constrained.
  attr_reader :enum #: Array[untyped]?

  # The default value, if any.
  attr_reader :default #: untyped

  # Element type for a typed array (+of:+).
  attr_reader :item_type #: Module?

  # Nested Params for object / array-of-object types.
  attr_reader :nested_params #: Riffer::Params?

  # Reconstructs a Param from a single JSON Schema property. Raises
  # Riffer::ArgumentError on a type outside the Params-expressible subset.
  #--
  #: (Symbol, Hash[Symbol, untyped], required: bool) -> Riffer::Params::Param
  def self.from_json_schema(name, schema, required:)
    ruby_type = json_type_to_ruby(schema[:type])
    item_type, nested = resolve_nesting(ruby_type, schema)

    new(
      name: name,
      type: ruby_type,
      required: required,
      description: schema[:description],
      enum: schema[:enum],
      default: schema[:default],
      item_type: item_type,
      nested_params: nested,
    )
  end

  #--
  #: (Module, Hash[Symbol, untyped]) -> [Module?, Riffer::Params?]
  def self.resolve_nesting(ruby_type, schema)
    return [nil, Riffer::Params.from_json_schema(schema)] if ruby_type == Hash && schema[:properties]
    return [nil, nil] unless ruby_type == Array

    items = schema[:items]
    return [nil, nil] unless items.is_a?(Hash)
    return [nil, Riffer::Params.from_json_schema(items)] if items[:properties]

    [json_type_to_ruby(items[:type]), nil]
  end
  private_class_method :resolve_nesting

  # Resolves a JSON Schema +type+ (or a <tt>[type, "null"]</tt> union) to its
  # Ruby type. Returns a Module — Riffer::Params::Boolean is a Module, not a
  # Class. Raises Riffer::ArgumentError on an unsupported type.
  #--
  #: (untyped) -> Module
  def self.json_type_to_ruby(type)
    key = type.is_a?(Array) ? type.find { |t| t != "null" } : type
    JSON_TYPE_MAPPINGS.fetch(key) { raise Riffer::ArgumentError, "Unsupported JSON Schema type: #{type.inspect}" }
  end
  private_class_method :json_type_to_ruby

  #--
  #: (name: Symbol, type: Module, required: bool, ?description: String?, ?enum: Array[untyped]?, ?default: untyped, ?item_type: Module?, ?nested_params: Riffer::Params?) -> void
  def initialize(name:, type:, required:, description: nil, enum: nil, default: nil, item_type: nil, nested_params: nil)
    @name = name.to_sym
    @type = type
    @required = required
    @description = description
    @enum = enum
    @default = default
    @item_type = item_type
    @nested_params = nested_params
  end

  # Validates that a value matches the expected type.
  #
  #--
  #: (untyped) -> bool
  def valid_type?(value)
    return true if value.nil? && !required

    if [Riffer::Params::Boolean, TrueClass, FalseClass].include?(type)
      [true, false].include?(value)
    else
      value.is_a?(type)
    end
  end

  # Returns the JSON Schema type name for this parameter.
  #
  #--
  #: () -> String
  def type_name
    TYPE_MAPPINGS[type] || type.to_s.downcase
  end

  # Converts this parameter to JSON Schema format. When +strict+, optional
  # params are made nullable (<tt>["type", "null"]</tt>) so strict providers
  # distinguish absent from present; optional params with an +enum+ use +anyOf+
  # instead, since providers like Anthropic reject
  # <tt>{"type": ["string", "null"], "enum": [...]}</tt>.
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    nullable = strict && !required

    if nullable && enum
      schema = { anyOf: [{ type: type_name, enum: enum }, { type: "null" }] } #: Hash[Symbol, untyped]
      schema[:description] = description if description
      return schema
    end

    type = type_name
    type = [type, "null"] if nullable

    schema = { type: type } #: Hash[Symbol, untyped]
    schema[:description] = description if description
    schema[:enum] = enum if enum
    # Strict providers reject the +default+ keyword; emit it only in
    # non-strict mode, where it makes the schema a lossless round-trip
    # source for +from_json_schema+.
    schema[:default] = default unless strict || default.nil?

    if self.type == Array && nested_params
      schema[:items] = nested_params.to_json_schema(strict: strict)
    elsif self.type == Array && item_type
      schema[:items] = { type: TYPE_MAPPINGS[item_type] }
    elsif self.type == Hash && nested_params
      schema.merge!(nested_params.to_json_schema(strict: strict))
    end

    schema
  end
end
