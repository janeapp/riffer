# frozen_string_literal: true

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
  DEFAULT_TIMEOUT = 10

  class << self
    include Riffer::Helpers::ClassNameConverter

    # Gets or sets the tool description.
    #
    # value:: String or nil - the description to set, or nil to get
    #
    # Returns String or nil - the tool description.
    def description(value = nil)
      return @description if value.nil?
      @description = value.to_s
    end

    # Gets or sets the tool identifier/name.
    #
    # value:: String or nil - the identifier to set, or nil to get
    #
    # Returns String - the tool identifier (defaults to snake_case class name).
    def identifier(value = nil)
      return @identifier || class_name_to_path(Module.instance_method(:name).bind_call(self)) if value.nil?
      @identifier = value.to_s
    end

    # Alias for identifier - used by providers
    alias_method :name, :identifier

    # Gets or sets the tool timeout in seconds.
    #
    # value:: Numeric or nil - the timeout to set in seconds, or nil to get
    #
    # Returns Numeric - the tool timeout (defaults to 10).
    def timeout(value = nil)
      return @timeout || DEFAULT_TIMEOUT if value.nil?
      @timeout = value.to_f
    end

    # Defines parameters using the Params DSL.
    #
    # Yields to the parameter definition block.
    #
    # Returns Riffer::Tools::Params or nil - the params builder.
    def params(&block)
      return @params_builder if block.nil?
      @params_builder = Riffer::Tools::Params.new
      @params_builder.instance_eval(&block)
    end

    # Returns the JSON Schema for the tool's parameters.
    #
    # Returns Hash - the JSON Schema.
    def parameters_schema
      @params_builder&.to_json_schema || empty_schema
    end

    private

    def empty_schema
      {type: "object", properties: {}, required: [], additionalProperties: false}
    end
  end

  # Executes the tool with the given arguments.
  #
  # context:: Object or nil - optional context passed from the agent
  # kwargs:: Hash - the tool arguments
  #
  # Returns Object - the tool result.
  #
  # Raises NotImplementedError if not implemented by subclass.
  def call(context:, **kwargs)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  # Executes the tool with validation and timeout (used by Agent).
  #
  # context:: Object or nil - context passed from the agent
  # kwargs:: Hash - the tool arguments
  #
  # Returns Riffer::Tools::Response - the tool response.
  #
  # Raises Riffer::ValidationError if validation fails.
  # Raises Riffer::TimeoutError if execution exceeds the configured timeout.
  # Raises Riffer::Error if the tool does not return a Response object.
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
