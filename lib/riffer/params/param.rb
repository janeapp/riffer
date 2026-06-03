# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Params::Param represents a single parameter definition.
#
# Handles type validation and JSON Schema generation for individual parameters.
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
    Hash => "object"
  }.freeze #: Hash[Module, String]

  # Primitive types allowed for the <tt>of:</tt> keyword on Array params
  PRIMITIVE_TYPES = (TYPE_MAPPINGS.keys - [Array, Hash]).freeze #: Array[Module]

  # Maps JSON Schema type strings back to Ruby types. The inverse of
  # TYPE_MAPPINGS, collapsing the three boolean spellings onto
  # Riffer::Params::Boolean. Used by +from_json_schema+.
  JSON_TYPE_MAPPINGS = {
    "string" => String,
    "integer" => Integer,
    "number" => Float,
    "boolean" => Riffer::Params::Boolean,
    "array" => Array,
    "object" => Hash
  }.freeze #: Hash[String, Module]

  attr_reader :name #: Symbol
  attr_reader :type #: Module
  attr_reader :required #: bool
  attr_reader :description #: String?
  attr_reader :enum #: Array[untyped]?
  attr_reader :default #: untyped
  attr_reader :item_type #: Module?
  attr_reader :nested_params #: Riffer::Params?

  #--
  # Reconstructs a Param from a single JSON Schema property.
  #
  # [name] the parameter name (Symbol).
  # [schema] the property's JSON Schema (Symbol-keyed).
  # [required] whether the property appeared in the parent's +required+ list.
  #
  # Raises Riffer::ArgumentError on a type outside the Params-expressible subset.
  #
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
      nested_params: nested
    )
  end

  # Resolves the +[item_type, nested_params]+ pair for a reconstructed Param:
  # a nested Params for object / array-of-object schemas, an +item_type+ for
  # typed primitive arrays, and +nil+ for everything else.
  #
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

  # Resolves a JSON Schema +type+ (a String, or a <tt>[type, "null"]</tt>
  # union) back to its Ruby type. Returns a Module because
  # Riffer::Params::Boolean is a Module, not a Class — the same widening the
  # +type+ attribute uses. Raises Riffer::ArgumentError on a type outside the
  # Params-expressible subset (the block runs only for an unmapped type).
  #
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

    if type == Riffer::Params::Boolean || type == TrueClass || type == FalseClass
      value == true || value == false
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

  # Converts this parameter to JSON Schema format.
  #
  # When +strict+ is true, optional parameters are made nullable
  # (<tt>["type", "null"]</tt>) so that strict mode providers can distinguish
  # "absent" from "present" without rejecting the schema.
  #
  # Optional parameters with an +enum+ use +anyOf+ to separate the enum
  # constraint from the null type, since providers like Anthropic reject
  # <tt>{"type": ["string", "null"], "enum": [...]}</tt>.
  #
  # In non-strict mode a +default+ is emitted when set (a standard JSON
  # Schema keyword), making the schema a lossless source for
  # +Riffer::Params.from_json_schema+. Strict mode omits it, since strict
  # providers reject the keyword.
  #
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    nullable = strict && !required

    if nullable && enum
      schema = {anyOf: [{type: type_name, enum: enum}, {type: "null"}]} #: Hash[Symbol, untyped]
      schema[:description] = description if description
      return schema
    end

    type = type_name
    type = [type, "null"] if nullable

    schema = {type: type} #: Hash[Symbol, untyped]
    schema[:description] = description if description
    schema[:enum] = enum if enum
    # Strict providers reject the +default+ keyword; emit it only in
    # non-strict mode, where it makes the schema a lossless round-trip
    # source for +from_json_schema+.
    schema[:default] = default unless strict || default.nil?

    if self.type == Array && nested_params
      schema[:items] = nested_params.to_json_schema(strict: strict)
    elsif self.type == Array && item_type
      schema[:items] = {type: TYPE_MAPPINGS[item_type]}
    elsif self.type == Hash && nested_params
      schema.merge!(nested_params.to_json_schema(strict: strict))
    end

    schema
  end
end
