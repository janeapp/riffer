# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::StructuredOutput
  attr_reader :params #: Riffer::Params # @dynamic params

  #--
  #: (Riffer::Params) -> void
  def initialize(params)
    @params = params
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def json_schema(strict: false)
    @params.to_json_schema(strict: strict)
  end

  #--
  #: (String) -> Riffer::Agent::StructuredOutput::Result
  def parse_and_validate(json_string)
    parsed = Riffer::Agent::StructuredOutput::Parser.parse(json_string)
    return Result.new(error: "JSON parse error: no JSON object found in the response") if parsed.nil?

    validated = @params.validate(parsed)
    Result.new(object: validated)
  rescue Riffer::ValidationError => e
    Result.new(error: "Validation error: #{e.message}")
  end
end
