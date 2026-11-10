# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::DeferredToolGateway::Tool < Riffer::Tool
  identifier Riffer::Providers::DeferredToolGateway::NAME
  description "Calls a tool that another tool has loaded. The result of the tool that loaded it lists its name " \
              "and parameters."

  # The arguments are a string rather than an object, since strict mode rejects an object without fixed properties.
  params do
    required :name, :string, description: "The name of the loaded tool to call"
    required :arguments, :string,
             description: "The loaded tool's arguments as a JSON-encoded object, such as " \
                          "{\"date\":\"2026-11-06\"}. Use {} for a tool without parameters."
  end
end
