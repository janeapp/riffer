# frozen_string_literal: true
# rbs_inline: enabled

require "timeout"

class Riffer::Tool
  extend Riffer::Registrable

  # @rbs self.@description: String?
  # @rbs self.@identifier: String?
  # @rbs self.@timeout: (Integer | Float)?
  # @rbs self.@params_builder: Riffer::Params?

  DEFAULT_TIMEOUT = 10 #: Integer

  class << self
    #--
    #: (?String?) -> String?
    def description(value = nil)
      return @description if value.nil?

      @description = value.to_s
    end

    #--
    #: (?String?) -> String
    def identifier(value = nil)
      return @identifier || Riffer::Helpers::Identifier.for(self) if value.nil?

      @identifier = value.to_s
    end

    #--
    #: (?String?) -> String
    def name(value = nil)
      return identifier(value) if value

      identifier
    end

    #--
    #: (?(Integer | Float)?) -> (Integer | Float)
    def timeout(value = nil)
      return @timeout || DEFAULT_TIMEOUT if value.nil?

      @timeout = value.to_f
    end

    #--
    #: () ?{ (Riffer::Params) [self: Riffer::Params] -> void } -> Riffer::Params?
    def params(&block)
      return @params_builder if block.nil?

      builder = Riffer::Params.new
      builder.instance_eval(&block)
      @params_builder = builder
    end

    #--
    #: (?strict: bool) -> Hash[Symbol, untyped]
    def parameters_schema(strict: false)
      @params_builder&.to_json_schema(strict: strict) || empty_schema
    end

    #--
    #: (?strict: bool) -> Hash[Symbol, untyped]
    def to_tool_schema(strict: false)
      {
        name: name,
        description: description,
        parameters_schema: parameters_schema(strict: strict),
      }
    end

    #--
    #: () -> true
    def validate_as_tool!
      if description.nil? || description.to_s.strip.empty?
        raise Riffer::ArgumentError,
              "#{self} must define a description"
      end
      raise Riffer::ArgumentError, "#{self} must have an identifier" if identifier.nil? || identifier.to_s.strip.empty?

      true
    end

    private

    def empty_schema # :nodoc:
      properties = {} #: Hash[Symbol, untyped]
      required = [] #: Array[untyped]
      { type: "object", properties: properties, required: required, additionalProperties: false }
    end
  end

  #--
  #: (context: Riffer::Agent::Context?, **untyped) -> Riffer::Tools::Response
  def call(context:, **kwargs)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  #--
  #: (untyped) -> Riffer::Tools::Response
  def text(result)
    Riffer::Tools::Response.text(result)
  end

  #--
  #: (untyped) -> Riffer::Tools::Response
  def json(result)
    Riffer::Tools::Response.json(result)
  end

  #--
  #: (Array[singleton(Riffer::Tool)]) -> Riffer::Tools::Response
  def load_tools(tools)
    Riffer::Tools::Response.load_tools(tools)
  end

  #--
  #: (String, ?type: Symbol) -> Riffer::Tools::Response
  def error(message, type: :execution_error)
    Riffer::Tools::Response.error(message, type: type)
  end

  #--
  #: (context: Riffer::Agent::Context?, **untyped) -> Riffer::Tools::Response
  def call_with_validation(context:, **kwargs)
    params_builder = self.class.params

    begin
      validated_args = params_builder ? params_builder.validate(kwargs) : kwargs
    rescue Riffer::ValidationError => e
      return Riffer::Tools::Response.error(e.message, type: :validation_error)
    end

    result = Timeout.timeout(self.class.timeout, Riffer::TimeoutError) do
      call(context: context, **validated_args) #: untyped
    end

    unless result.is_a?(Riffer::Tools::Response)
      raise Riffer::Error, "#{self.class} must return a Riffer::Tools::Response from #call"
    end

    result
  rescue Riffer::TimeoutError
    Riffer::Tools::Response.error(
      "Tool execution timed out after #{self.class.timeout} seconds",
      type: :timeout_error,
    )
  rescue Riffer::ToolExecutionError => e
    Riffer::Tools::Response.error(e.message, type: :execution_error)
  # Anything outside StandardError — an unimplemented #call above all — still
  # propagates: a broken tool is a broken deploy, not a bad request.
  rescue StandardError => e
    Riffer::Tools::Response.error(
      "Error executing tool: #{e.class}: #{e.message}",
      type: :unhandled_error,
      exception: e,
    )
  end
end
