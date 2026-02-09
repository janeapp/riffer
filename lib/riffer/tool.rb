# frozen_string_literal: true
# rbs_inline: enabled

require "timeout"

# Riffer::Tool is the base class for all tools in the Riffer framework.
#
# Provides a DSL for defining tool description and parameters.
# Subclasses must implement the +call+ method.
#
# See Riffer::Agent.
#
#   class WeatherLookupTool < Riffer::Tool
#     description "Provides current weather information for a specified city."
#
#     params do
#       required :city, String, description: "The city to look up"
#       optional :units, String, default: "celsius"
#     end
#
#     def call(context:, city:, units: nil)
#       # Implementation
#     end
#   end
#
class Riffer::Tool
  DEFAULT_TIMEOUT = 10 #: Integer

  # Some providers do not allow "/" in tool names, so we use "__" as separator.
  TOOL_SEPARATOR = "__" #: String

  extend Riffer::Helpers::ClassNameConverter

  #: self.@description: String?
  #: self.@identifier: String?
  #: self.@timeout: Float?
  #: self.@params_builder: Riffer::Tools::Params?

  # Gets or sets the tool description.
  #
  #: value: String? -- the description to set, or nil to get
  #: return: String?
  def self.description(value = nil)
    return @description if value.nil?
    @description = value.to_s
  end

  # Gets or sets the tool identifier/name.
  #
  #: value: String? -- the identifier to set, or nil to get
  #: return: String
  def self.identifier(value = nil)
    return @identifier || class_name_to_path(Module.instance_method(:name).bind_call(self), separator: TOOL_SEPARATOR) if value.nil?
    @identifier = value.to_s
  end

  # Alias for identifier - used by providers.
  #
  #: value: String? -- the name to set, or nil to get
  #: return: String
  def self.name(value = nil)
    return identifier(value) unless value.nil?
    identifier
  end

  # Gets or sets the tool timeout in seconds.
  #
  #: value: (Integer | Float)? -- the timeout to set in seconds, or nil to get
  #: return: (Integer | Float)
  def self.timeout(value = nil)
    return @timeout || DEFAULT_TIMEOUT if value.nil?
    @timeout = value.to_f
  end

  # Defines parameters using the Params DSL.
  #
  #: &block: () -> void
  #: return: Riffer::Tools::Params?
  def self.params(&block)
    return @params_builder if block.nil?
    @params_builder = Riffer::Tools::Params.new
    @params_builder.instance_eval(&block)
  end

  # Returns the JSON Schema for the tool's parameters.
  #
  #: return: Hash[Symbol, untyped]
  def self.parameters_schema
    @params_builder&.to_json_schema || empty_schema
  end

  def self.empty_schema # :nodoc:
    {type: "object", properties: {}, required: [], additionalProperties: false}
  end
  private_class_method :empty_schema

  # Executes the tool with the given arguments.
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #: context: Hash[Symbol, untyped]? -- optional context passed from the agent
  #: **kwargs: untyped
  #: return: Riffer::Tools::Response
  def call(context:, **kwargs)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  # Creates a text response. Shorthand for Riffer::Tools::Response.text.
  #
  #: result: untyped -- the tool result (converted via to_s)
  #: return: Riffer::Tools::Response
  def text(result)
    Riffer::Tools::Response.text(result)
  end

  # Creates a JSON response. Shorthand for Riffer::Tools::Response.json.
  #
  #: result: untyped -- the tool result (converted via JSON.generate)
  #: return: Riffer::Tools::Response
  def json(result)
    Riffer::Tools::Response.json(result)
  end

  # Creates an error response. Shorthand for Riffer::Tools::Response.error.
  #
  #: message: String -- the error message
  #: type: Symbol -- the error type (default: :execution_error)
  #: return: Riffer::Tools::Response
  def error(message, type: :execution_error)
    Riffer::Tools::Response.error(message, type: type)
  end

  # Executes the tool with validation and timeout (used by Agent).
  #
  # Raises Riffer::ValidationError if validation fails.
  # Raises Riffer::TimeoutError if execution exceeds the configured timeout.
  # Raises Riffer::Error if the tool does not return a Response object.
  #
  #: context: Hash[Symbol, untyped]? -- context passed from the agent
  #: **kwargs: untyped
  #: return: Riffer::Tools::Response
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
