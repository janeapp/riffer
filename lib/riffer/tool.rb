# frozen_string_literal: true
# rbs_inline: enabled

require "timeout"

# Base class for all tools in the Riffer framework. Subclasses must implement
# the +call+ method.
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
  extend Riffer::Tools::Toolable

  kind :tool

  # Executes the tool with the given arguments.
  #--
  #: (context: Riffer::Agent::Context?, **untyped) -> Riffer::Tools::Response
  def call(context:, **kwargs)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  # Creates a text response.
  #
  #--
  #: (untyped) -> Riffer::Tools::Response
  def text(result)
    Riffer::Tools::Response.text(result)
  end

  # Creates a JSON response.
  #
  #--
  #: (untyped) -> Riffer::Tools::Response
  def json(result)
    Riffer::Tools::Response.json(result)
  end

  # Creates an error response.
  #
  #--
  #: (String, ?type: Symbol) -> Riffer::Tools::Response
  def error(message, type: :execution_error)
    Riffer::Tools::Response.error(message, type: type)
  end

  # Executes the tool with validation and timeout (used by Agent).
  #
  # Raises Riffer::ValidationError if validation fails.
  # Raises Riffer::TimeoutError if execution exceeds the configured timeout.
  # Raises Riffer::Error if the tool does not return a Response object.
  #
  #--
  #: (context: Riffer::Agent::Context?, **untyped) -> Riffer::Tools::Response
  def call_with_validation(context:, **kwargs)
    params_builder = self.class.params
    validated_args = params_builder ? params_builder.validate(kwargs) : kwargs

    result = Timeout.timeout(self.class.timeout) do
      call(context: context, **validated_args) #: untyped
    end

    unless result.is_a?(Riffer::Tools::Response)
      raise Riffer::Error, "#{self.class} must return a Riffer::Tools::Response from #call"
    end

    result
  rescue Timeout::Error
    raise Riffer::TimeoutError, "Tool execution timed out after #{self.class.timeout} seconds"
  end
end
