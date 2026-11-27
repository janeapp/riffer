# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Params::Param
  PRIMITIVE_TYPES = %i[string integer number boolean].freeze #: Array[Symbol]

  TYPES = [*PRIMITIVE_TYPES, :array, :object, :any_of].freeze #: Array[Symbol]

  CLASS_TYPES = {
    String => :string,
    Integer => :integer,
    Float => :number,
    Riffer::Params::Boolean => :boolean,
    TrueClass => :boolean,
    FalseClass => :boolean,
    Array => :array,
    Hash => :object,
    Riffer::Params::AnyOf => :any_of,
  }.freeze #: Hash[Module, Symbol]

  JSON_TYPE_MAPPINGS = (TYPES - [:any_of]).to_h { |type| [type.name, type] }.freeze #: Hash[String, Symbol]

  attr_reader :name #: Symbol # @dynamic name

  attr_reader :type #: Symbol # @dynamic type

  attr_reader :required #: bool # @dynamic required

  attr_reader :description #: String? # @dynamic description

  attr_reader :enum #: Array[untyped]? # @dynamic enum

  attr_reader :format #: String? # @dynamic format

  attr_reader :default #: untyped # @dynamic default

  attr_reader :item_type #: Symbol? # @dynamic item_type

  attr_reader :dimensions #: Integer # @dynamic dimensions

  attr_reader :nested_params #: Riffer::Params? # @dynamic nested_params

  attr_reader :variants #: Array[Riffer::Params | Riffer::Params::Param]? # @dynamic variants

  #--
  #: (untyped) -> Symbol?
  def self.resolve_type(type)
    return type if TYPES.include?(type)

    symbol = CLASS_TYPES[type] #: Symbol?
    return unless symbol

    Riffer::Deprecation.warn(
      id: :param_class_types,
      message: "#{type.name} as a param type is deprecated and will be removed in a future version, " \
               "not before 1 December 2026; use #{symbol.inspect}.",
    )
    symbol
  end

  #--
  #: (untyped, String, Array[Symbol]) -> Symbol
  def self.resolve_type!(type, subject, allowed)
    resolved = resolve_type(type)
    return resolved if resolved && allowed.include?(resolved)

    raise Riffer::ArgumentError, "#{subject} must be one of #{allowed.map(&:inspect).join(', ')}, got #{type.inspect}"
  end

  #--
  #: (Symbol, untyped) -> bool
  def self.value_of_type?(type, value)
    case type
    when :string then value.is_a?(String)
    when :integer then value.is_a?(Integer)
    when :number then value.is_a?(Numeric)
    when :boolean then [true, false].include?(value)
    when :array then value.is_a?(Array)
    when :object then value.is_a?(Hash)
    else false
    end
  end

  #--
  #: (Symbol, Hash[Symbol, untyped], required: bool) -> Riffer::Params::Param
  def self.from_json_schema(name, schema, required:)
    variants = resolve_variants(name, schema[:anyOf]) if schema.key?(:anyOf)
    type = variants ? :any_of : json_type(schema[:type])
    nested = resolve_nested_params(type, schema)
    item_type, dimensions, items = resolve_typed_items(schema) if type == :array && !nested

    new(
      name: name,
      type: type,
      required: required,
      description: schema[:description],
      enum: schema[:enum] || items&.dig(:enum),
      format: schema[:format] || items&.dig(:format),
      default: schema[:default],
      item_type: item_type,
      dimensions: dimensions || 1,
      nested_params: nested,
      variants: variants,
    )
  end

  #--
  #: (Symbol, Array[Hash[Symbol, untyped]]) -> Array[Riffer::Params | Riffer::Params::Param]
  def self.resolve_variants(name, branches)
    # Strict schemas add a null branch to optional fields; nullability comes from +required+.
    variants = branches.reject { |branch| branch[:type] == "null" }.map do |branch|
      if branch[:type] == "object"
        Riffer::Params.from_json_schema(branch)
      elsif PRIMITIVE_TYPES.include?(JSON_TYPE_MAPPINGS[branch[:type]]) && !branch.key?(:anyOf)
        from_json_schema(name, branch, required: true)
      else
        raise Riffer::ArgumentError, "Unsupported anyOf branch: #{branch.to_json}"
      end
    end
    raise Riffer::ArgumentError, "anyOf requires at least two branches" if variants.size < 2

    variants
  end
  private_class_method :resolve_variants

  #--
  #: (Symbol, Hash[Symbol, untyped]) -> Riffer::Params?
  def self.resolve_nested_params(type, schema)
    if type == :object && schema[:properties]
      Riffer::Params.from_json_schema(schema)
    elsif type == :array && schema[:items].is_a?(Hash) && schema[:items][:properties]
      Riffer::Params.from_json_schema(schema[:items])
    end
  end
  private_class_method :resolve_nested_params

  #--
  #: (Hash[Symbol, untyped]) -> [Symbol, Integer, Hash[Symbol, untyped]]?
  def self.resolve_typed_items(schema)
    items = schema[:items]
    return unless items.is_a?(Hash)

    dimensions = 1
    # Riffer only writes nested arrays with enum/format and a single primitive type on the innermost
    # items, and no nullable inner arrays; any other shape would read back with a different meaning.
    while json_type(items[:type]) == :array
      inner = items[:items]
      unless items[:type] == "array" && inner.is_a?(Hash) && !items.keys.intersect?(%i[enum format])
        raise Riffer::ArgumentError, "Unsupported nested array: #{items.to_json}"
      end

      items = inner
      dimensions += 1
    end

    item_type = json_type(items[:type])
    if dimensions > 1
      if schema.keys.intersect?(%i[enum format])
        raise Riffer::ArgumentError, "Unsupported nested array: #{schema.to_json}"
      end
      unless items[:type].is_a?(String) && PRIMITIVE_TYPES.include?(item_type)
        raise Riffer::ArgumentError, "Unsupported nested array items: #{items.to_json}"
      end
    end

    [item_type, dimensions, items]
  end
  private_class_method :resolve_typed_items

  #--
  #: (untyped) -> Symbol
  def self.json_type(type)
    types = Array(type) - ["null"]
    symbol = JSON_TYPE_MAPPINGS[types.first] if types.one?
    symbol || raise(Riffer::ArgumentError, "Unsupported JSON Schema type: #{type.inspect}")
  end
  private_class_method :json_type

  #--
  #: (name: Symbol, type: Symbol, required: bool, ?description: String?, ?enum: Array[untyped]?, ?format: String?, ?default: untyped, ?item_type: Symbol?, ?dimensions: Integer, ?nested_params: Riffer::Params?, ?variants: Array[Riffer::Params | Riffer::Params::Param]?) -> void
  def initialize(name:, type:, required:, description: nil, enum: nil, format: nil, default: nil, item_type: nil,
                 dimensions: 1, nested_params: nil, variants: nil)
    raise Riffer::ArgumentError, "#{name}: an :any_of param requires variants" if type == :any_of && variants.nil?

    @name = name.to_sym
    @type = type
    @required = required
    @description = description
    @enum = enum
    # Frozen and deduplicated, so copies never share a mutable string.
    @format = format.is_a?(String) ? -format : format
    @default = default
    @item_type = item_type
    @dimensions = dimensions
    @nested_params = nested_params
    @variants = variants
    # Checked here rather than in Params so from_json_schema enforces them too.
    validate_format! if format
    validate_variant_order! if variants
  end

  #--
  #: (untyped) -> bool
  def valid_type?(value)
    return true if value.nil? && !required

    if type == :any_of
      Array(variants).any? { |variant| variant.is_a?(Riffer::Params) ? value.is_a?(Hash) : variant.valid_type?(value) }
    else
      self.class.value_of_type?(type, value)
    end
  end

  #--
  #: () -> String
  def type_name
    if type == :any_of
      names = Array(variants).map { |variant| variant.is_a?(Riffer::Params) ? "object" : variant.type_name }
      return names.uniq.join(" or ")
    end

    type.name
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    validate_strict_shape! if strict
    # Nullable so strict providers can distinguish absent from present.
    nullable = strict && !required

    if type == :any_of && variants
      schema = { anyOf: variants.map { |variant| variant.to_json_schema(strict: strict) } } #: Hash[Symbol, untyped]
      schema[:anyOf] << { type: "null" } if nullable
      schema[:description] = description if description
      schema[:default] = default unless strict || default.nil?
      return schema
    end

    # A typed array's enum and format constrain its items, not the array.
    value_enum = enum unless item_type
    value_format = format unless item_type

    # Providers like Anthropic reject a nullable type union combined with enum.
    if nullable && value_enum
      schema = { anyOf: [{ type: type_name, enum: value_enum }, { type: "null" }] } #: Hash[Symbol, untyped]
      schema[:description] = description if description
      return schema
    end

    type = type_name
    type = [type, "null"] if nullable

    schema = { type: type } #: Hash[Symbol, untyped]
    schema[:description] = description if description
    schema[:enum] = value_enum if value_enum
    schema[:format] = value_format if value_format
    # Strict providers reject the +default+ keyword; emit it only in
    # non-strict mode, where it makes the schema a lossless round-trip
    # source for +from_json_schema+.
    schema[:default] = default unless strict || default.nil?

    if self.type == :array && nested_params
      schema[:items] = nested_params.to_json_schema(strict: strict)
    elsif self.type == :array && item_type
      items = { type: item_type.name, enum: enum, format: format }.compact #: Hash[Symbol, untyped]
      (dimensions - 1).times { items = { type: "array", items: items } }
      schema[:items] = items
    elsif self.type == :object && nested_params
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
    @variants = source.variants&.map(&:dup)
    @enum = Riffer::Helpers::DeepDup.call(source.enum)
    @default = Riffer::Helpers::DeepDup.call(source.default)
  end

  # The first matching variant wins, and a :number variant without an enum accepts any number.
  #--
  #: () -> void
  def validate_variant_order!
    primitives = Array(variants).grep(Riffer::Params::Param) #: Array[Riffer::Params::Param]
    number = primitives.index { |variant| variant.type == :number && variant.enum.nil? }
    integer = primitives.rindex { |variant| variant.type == :integer }
    return unless number && integer && number < integer

    raise Riffer::ArgumentError, "#{name}: an :integer variant after a :number variant without enum: can never match"
  end

  #--
  #: () -> void
  def validate_format!
    unless Riffer::Params::Format::NAMES.include?(format)
      raise Riffer::ArgumentError,
            "#{name}: format: must be a supported format (#{Riffer::Params::Format::NAMES.join(', ')}), " \
            "got #{format.inspect}"
    end
    unless type == :string || (type == :array && item_type == :string)
      raise Riffer::ArgumentError, "#{name}: format: requires :string or an :array whose innermost type is :string"
    end
    raise Riffer::ArgumentError, "#{name}: format: cannot be used with enum:" if enum
  end

  #--
  #: () -> void
  def validate_strict_shape!
    # Strict providers reject objects without properties and arrays without items.
    if type == :object && nested_params.nil?
      raise Riffer::ArgumentError,
            "#{name}: an :object param requires a block defining its properties under strict schemas"
    elsif type == :array && nested_params.nil? && item_type.nil?
      raise Riffer::ArgumentError,
            "#{name}: an :array param requires a block or of: defining its items under strict schemas"
    end
  end
end
