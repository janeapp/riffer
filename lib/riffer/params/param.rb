# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Params::Param
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

  PRIMITIVE_TYPES = (TYPE_MAPPINGS.keys - [Array, Hash]).freeze #: Array[Module]

  JSON_TYPE_MAPPINGS = {
    "string" => String,
    "integer" => Integer,
    "number" => Float,
    "boolean" => Riffer::Params::Boolean,
    "array" => Array,
    "object" => Hash,
  }.freeze #: Hash[String, Module]

  attr_reader :name #: Symbol # @dynamic name

  attr_reader :type #: Module # @dynamic type

  attr_reader :required #: bool # @dynamic required

  attr_reader :description #: String? # @dynamic description

  attr_reader :enum #: Array[untyped]? # @dynamic enum

  attr_reader :default #: untyped # @dynamic default

  attr_reader :item_type #: Module? # @dynamic item_type

  attr_reader :nested_params #: Riffer::Params? # @dynamic nested_params

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

  #--
  #: (untyped) -> bool
  def valid_type?(value)
    return true if value.nil? && !required

    if [Riffer::Params::Boolean, TrueClass, FalseClass].include?(type)
      [true, false].include?(value)
    elsif type == Float
      value.is_a?(Numeric)
    else
      value.is_a?(type)
    end
  end

  #--
  #: () -> String
  def type_name
    TYPE_MAPPINGS[type] || type.to_s.downcase
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    validate_strict_shape! if strict
    # Nullable so strict providers can distinguish absent from present.
    nullable = strict && !required

    # Providers like Anthropic reject a nullable type union combined with enum.
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
      # The nested schema carries its own type: "object", which would clobber a nullable union.
      schema.merge!(nested_params.to_json_schema(strict: strict).except(:type))
    end

    schema
  end

  private

  # +dup+ would leave the copy sharing this one's nested Params, enum list and
  # default, so defining a parameter or editing either value on one would reach
  # the other.
  #--
  #: (Riffer::Params::Param) -> void
  def initialize_copy(source)
    super
    @nested_params = source.nested_params&.dup
    @enum = Riffer::Helpers::DeepDup.call(source.enum)
    @default = Riffer::Helpers::DeepDup.call(source.default)
  end

  #--
  #: () -> void
  def validate_strict_shape!
    # Strict providers reject objects without properties and arrays without items.
    if type == Hash && nested_params.nil?
      raise Riffer::ArgumentError,
            "#{name}: a Hash param requires a block defining its properties under strict schemas"
    elsif type == Array && nested_params.nil? && item_type.nil?
      raise Riffer::ArgumentError,
            "#{name}: an Array param requires a block or of: defining its items under strict schemas"
    end
  end
end
