# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::StructuredOutput provides parse/validate for structured JSON
# responses from LLM providers.
#
#   params = Riffer::Params.new
#   params.required(:sentiment, String)
#   so = Riffer::StructuredOutput.new(params)
#   result = so.parse_and_validate('{"sentiment":"positive","score":0.9}')
#   result.object  #=> {sentiment: "positive", score: 0.9}
#
class Riffer::StructuredOutput
  attr_reader :params #: Riffer::Params
  attr_reader :json_schema #: Hash[Symbol, untyped]

  #: (Riffer::Params) -> void
  def initialize(params)
    @params = params
    @json_schema = @params.to_json_schema
  end

  # Parses a JSON string and validates it against the schema.
  #
  # Returns a Result with the validated object on success, or an error message on failure.
  #
  #: (String) -> Riffer::StructuredOutput::Result
  def parse_and_validate(json_string)
    parsed = JSON.parse(json_string)
    validated = @params.validate(parsed.transform_keys(&:to_sym))
    Result.new(object: validated)
  rescue JSON::ParserError => e
    Result.new(error: "JSON parse error: #{e.message}")
  rescue Riffer::ValidationError => e
    Result.new(error: "Validation error: #{e.message}")
  end
end
