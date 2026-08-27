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
  extend Riffer::Registrable

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

  # Executes the tool with validation and timeout, folding every +StandardError+
  # into an error Response. Anything outside +StandardError+ — an unimplemented
  # +#call+ above all — still propagates, because a broken tool is a broken
  # deploy rather than a bad request.
  #
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
  rescue StandardError => e
    Riffer::Tools::Response.error(
      "Error executing tool: #{e.class}: #{e.message}",
      type: :unhandled_error,
      exception: e,
    )
  end
end
