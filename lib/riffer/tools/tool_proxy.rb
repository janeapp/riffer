# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Tools::ToolProxy is a lightweight schema-only tool descriptor.
#
# Satisfies the provider contract (+.name+, +.description+, +.parameters_schema+)
# without being a real Tool class. Used by RpcExecutor so providers can format
# tool schemas for the LLM.
#
#   proxy = Riffer::Tools::ToolProxy.new(
#     name: "weather_lookup",
#     description: "Look up weather for a city"
#   )
#   proxy.name             # => "weather_lookup"
#   proxy.parameters_schema # => { type: "object", ... }
#
class Riffer::Tools::ToolProxy
  attr_reader :name #: String
  attr_reader :description #: String
  attr_reader :parameters_schema #: Hash[Symbol, untyped]

  #: (name: String, description: String, ?parameters_schema: Hash[Symbol, untyped]) -> void
  def initialize(name:, description:, parameters_schema: Riffer::Tool.send(:empty_schema))
    @name = name
    @description = description
    @parameters_schema = parameters_schema
  end
end
