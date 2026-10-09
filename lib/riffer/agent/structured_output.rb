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
    "When you give your final answer, respond with only a JSON object that conforms to " \
      "the following JSON Schema, with no other text before or after it:\n\n" \
      "#{JSON.generate(json_schema)}"
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
end
