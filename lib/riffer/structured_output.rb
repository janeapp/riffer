# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::StructuredOutput
  attr_reader :params #: Riffer::Params

  #: (Riffer::Params) -> void
  def initialize(params)
    @params = params
  end

  #: (?strict: bool) -> Hash[Symbol, untyped]
  def json_schema(strict: false)
    @params.to_json_schema(strict: strict)
  end

  #: (String) -> Riffer::StructuredOutput::Result
  def parse_and_validate(json_string)
    parsed = JSON.parse(json_string, symbolize_names: true)
    validated = @params.validate(parsed)
    Result.new(object: validated)
  rescue JSON::ParserError => e
    Result.new(error: "JSON parse error: #{e.message}")
  rescue Riffer::ValidationError => e
    Result.new(error: "Validation error: #{e.message}")
  end
end
