# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Param
  TYPE_MAPPINGS = {
    String => "string",
    Integer => "integer",
    Float => "number",
    Riffer::Boolean => "boolean",
    TrueClass => "boolean",
    FalseClass => "boolean",
    Array => "array",
    Hash => "object"
  }.freeze #: Hash[Module, String]

  PRIMITIVE_TYPES = (TYPE_MAPPINGS.keys - [Array, Hash]).freeze #: Array[Class]

  attr_reader :name #: Symbol
  attr_reader :type #: Class
  attr_reader :required #: bool
  attr_reader :description #: String?
  attr_reader :enum #: Array[untyped]?
  attr_reader :default #: untyped
  attr_reader :item_type #: Class?
  attr_reader :nested_params #: Riffer::Params?

  #: (name: Symbol, type: Class, required: bool, ?description: String?, ?enum: Array[untyped]?, ?default: untyped, ?item_type: Class?, ?nested_params: Riffer::Params?) -> void
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

  #: (untyped) -> bool
  def valid_type?(value)
    return true if value.nil? && !required

    if type == Riffer::Boolean || type == TrueClass || type == FalseClass
      value == true || value == false
    else
      value.is_a?(type)
    end
  end

  #: () -> String
  def type_name
    TYPE_MAPPINGS[type] || type.to_s.downcase
  end

  #: (?strict: bool) -> Hash[Symbol, untyped]
  def to_json_schema(strict: false)
    nullable = strict && !required

    if nullable && enum
      schema = {anyOf: [{type: type_name, enum: enum}, {type: "null"}]}
      schema[:description] = description if description
      return schema
    end

    type = type_name
    type = [type, "null"] if nullable

    schema = {type: type}
    schema[:description] = description if description
    schema[:enum] = enum if enum

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
