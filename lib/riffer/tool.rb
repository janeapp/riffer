# frozen_string_literal: true

# Riffer::Tool is the base class for all tools in the Riffer framework.
#
# Provides a DSL for defining tool description and parameters.
#
# @abstract Subclasses must implement the `call` method.
#
# @example
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
# @see Riffer::Agent
class Riffer::Tool
  class << self
    include Riffer::Helpers::ClassNameConverter

    # Gets or sets the tool description
    # @param value [String, nil] the description to set, or nil to get
    # @return [String, nil] the tool description
    def description(value = nil)
      return @description if value.nil?
      @description = value.to_s
    end

    # Gets or sets the tool identifier/name
    # @param value [String, nil] the identifier to set, or nil to get
    # @return [String] the tool identifier (defaults to snake_case class name)
    def identifier(value = nil)
      return @identifier || class_name_to_path(Module.instance_method(:name).bind_call(self)) if value.nil?
      @identifier = value.to_s
    end

    # Alias for identifier - used by providers
    alias_method :name, :identifier

    # Defines parameters using the Params DSL
    # @yield the parameter definition block
    # @return [Riffer::Tools::Params, nil] the params builder
    def params(&block)
      return @params_builder if block.nil?
      @params_builder = Riffer::Tools::Params.new
      @params_builder.instance_eval(&block)
    end

    # Returns the JSON Schema for the tool's parameters
    # @return [Hash] the JSON Schema
    def parameters_schema
      @params_builder&.to_json_schema || empty_schema
    end

    private

    def empty_schema
      {type: "object", properties: {}, required: [], additionalProperties: false}
    end
  end

  # Executes the tool with the given arguments
  # @param context [Object, nil] optional context passed from the agent
  # @param kwargs [Hash] the tool arguments
  # @return [Object] the tool result
  # @raise [NotImplementedError] if not implemented by subclass
  def call(context:, **kwargs)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  # Executes the tool with validation (used by Agent)
  # @param context [Object, nil] context passed from the agent
  # @param kwargs [Hash] the tool arguments
  # @return [Object] the tool result
  # @raise [Riffer::ValidationError] if validation fails
  def call_with_validation(context:, **kwargs)
    params_builder = self.class.params
    validated_args = params_builder ? params_builder.validate(kwargs) : kwargs
    call(context: context, **validated_args)
  end
end
