# frozen_string_literal: true
# rbs_inline: enabled

require "timeout"

class Riffer::Tool
  DEFAULT_TIMEOUT = 10 #: Integer

  # Some providers do not allow "/" in tool names, so we use "__" as separator.
  TOOL_SEPARATOR = "__" #: String

  extend Riffer::Helpers::ClassNameConverter

  #: (?String?) -> String?
  def self.description(value = nil)
    return @description if value.nil?
    @description = value.to_s
  end

  #: (?String?) -> String
  def self.identifier(value = nil)
    return @identifier || class_name_to_path(Module.instance_method(:name).bind_call(self), separator: TOOL_SEPARATOR) if value.nil?
    @identifier = value.to_s
  end

  #: (?String?) -> String
  def self.name(value = nil)
    return identifier(value) unless value.nil?
    identifier
  end

  #: (?(Integer | Float)?) -> (Integer | Float)
  def self.timeout(value = nil)
    return @timeout || DEFAULT_TIMEOUT if value.nil?
    @timeout = value.to_f
  end

  #: () ?{ () -> void } -> Riffer::Params?
  def self.params(&block)
    return @params_builder if block.nil?
    @params_builder = Riffer::Params.new
    @params_builder.instance_eval(&block)
  end

  #: (?strict: bool) -> Hash[Symbol, untyped]
  def self.parameters_schema(strict: false)
    @params_builder&.to_json_schema(strict: strict) || empty_schema
  end

  def self.empty_schema
    {type: "object", properties: {}, required: [], additionalProperties: false}
  end
  private_class_method :empty_schema

  #: (context: Hash[Symbol, untyped]?, **untyped) -> Riffer::Tools::Response
  def call(context:, **kwargs)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  #: (untyped) -> Riffer::Tools::Response
  def text(result)
    Riffer::Tools::Response.text(result)
  end

  #: (untyped) -> Riffer::Tools::Response
  def json(result)
    Riffer::Tools::Response.json(result)
  end

  #: (String, ?type: Symbol) -> Riffer::Tools::Response
  def error(message, type: :execution_error)
    Riffer::Tools::Response.error(message, type: type)
  end

  #: (context: Hash[Symbol, untyped]?, **untyped) -> Riffer::Tools::Response
  def call_with_validation(context:, **kwargs)
    params_builder = self.class.params
    validated_args = params_builder ? params_builder.validate(kwargs) : kwargs

    result = Timeout.timeout(self.class.timeout) do
      call(context: context, **validated_args)
    end

    unless result.is_a?(Riffer::Tools::Response)
      raise Riffer::Error, "#{self.class} must return a Riffer::Tools::Response from #call"
    end

    result
  rescue Timeout::Error
    raise Riffer::TimeoutError, "Tool execution timed out after #{self.class.timeout} seconds"
  end
end
