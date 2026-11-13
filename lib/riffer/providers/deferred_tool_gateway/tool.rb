# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::DeferredToolGateway::Tool < Riffer::Tool
  identifier "riffer_gateway"
  description "Calls a tool that another tool has loaded. The result of the tool that loaded it lists its name " \
              "and parameters."

  # The arguments are a string rather than an object, since strict mode rejects an object without fixed properties.
  params do
    required :name, :string, description: "The loaded tool's exact name, copied from the result that loaded it"
    required :arguments, :string,
             description: "The loaded tool's arguments as a JSON-encoded object string matching its parameters, " \
                          "such as \"{\\\"query\\\":\\\"red shoes\\\",\\\"limit\\\":5}\". Numbers and booleans " \
                          "stay unquoted inside it. Use \"{}\" for a tool without parameters."
  end
end
