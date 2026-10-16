# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Agent::StructuredOutput
  attr_reader :params #: Riffer::Params # @dynamic params
  attr_reader :strategy #: Symbol # @dynamic strategy

  #--
  #: (Riffer::Params, ?strategy: Symbol) -> void
  def initialize(params, strategy: :native)
    @params = params
    @strategy = strategy
  end

  #--
  #: () -> bool
  def prompted?
    @strategy == :prompted
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def json_schema(strict: false)
    @params.to_json_schema(strict: strict)
  end

  # Worded for the final answer only, so the model can still call tools first.
  #--
  #: () -> String
  def prompt_instructions
    schema = json_schema
    [
      "When you give your final answer, respond with only a JSON object that conforms to " \
      "the following JSON Schema, with no other text before or after it:",
      JSON.generate(schema),
      "Example of the shape (placeholder values):\n#{JSON.generate(placeholder(schema))}",
      "Only call tools when the request needs them. If you can answer directly, reply with the JSON object right away.",
    ].join("\n\n")
  end

  #--
  #: (String) -> Riffer::Agent::StructuredOutput::Result
  def parse_and_validate(json_string)
    json, parsed = Riffer::Agent::StructuredOutput::Parser.extract(json_string)
    return Result.new(error: "JSON parse error: no JSON object found in the response") if parsed.nil?

    validated = @params.validate(parsed)
    Result.new(object: validated, json: json)
  rescue Riffer::ValidationError => e
    Result.new(error: "Validation error: #{e.message}")
  end

  private

  #--
  #: (Hash[Symbol, untyped]) -> untyped
  def placeholder(schema)
    return schema[:enum].join(" | ") if schema[:enum]
    return placeholder(schema[:anyOf].first) if schema[:anyOf]

    case schema[:type]
    when "object" then (schema[:properties] || {}).transform_values { |property| placeholder(property) }
    when "array" then schema[:items] ? [placeholder(schema[:items])] : []
    else "<#{schema[:type]}>"
    end
  end
end
