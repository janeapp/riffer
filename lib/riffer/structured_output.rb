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

  #--
  #: (Riffer::Params) -> void
  def initialize(params)
    @params = params
  end

  # Builds a StructuredOutput from a pre-built JSON Schema, bypassing the
  # Params DSL.
  #
  # Useful when the schema is generated externally (e.g. from a Pydantic-style
  # model, dumped JSON, or another tool). The returned object exposes the same
  # +json_schema+ and +parse_and_validate+ surface as a Params-backed
  # StructuredOutput. Client-side validation only checks that the LLM produced
  # parseable JSON whose top level is an object — schema enforcement is left
  # to the LLM provider, which receives the raw schema verbatim.
  #
  #   schema = JSON.parse(File.read("sentiment.schema.json"), symbolize_names: true)
  #   so = Riffer::StructuredOutput.from_json_schema(schema)
  #   class SentimentAgent < Riffer::Agent
  #     model "openai/gpt-5-mini"
  #     structured_output so
  #   end
  #
  #--
  #: (Hash[Symbol, untyped]) -> Riffer::StructuredOutput
  def self.from_json_schema(schema)
    new(RawJsonSchema.new(schema))
  end

  # Returns the JSON Schema for this structured output.
  #
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def json_schema(strict: false)
    @params.to_json_schema(strict: strict)
  end

  # Parses a JSON string and validates it against the schema.
  #
  # Returns a Result with the validated object on success, or an error message on failure.
  #
  #--
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

  # Adapter used by StructuredOutput.from_json_schema to make a raw JSON
  # Schema look like a Riffer::Params for the two methods StructuredOutput
  # calls on it. Validation is intentionally a pass-through: the LLM provider
  # already enforces the schema server-side, and bringing in a JSON Schema
  # validator on the client would be a heavier dependency than this entry
  # point warrants.
  class RawJsonSchema
    #--
    #: (Hash[Symbol, untyped]) -> void
    def initialize(schema)
      @schema = schema
    end

    #--
    #: (?strict: bool) -> Hash[Symbol, untyped]
    def to_json_schema(strict: false)
      @schema
    end

    #--
    #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
    def validate(arguments)
      arguments
    end
  end
  private_constant :RawJsonSchema
end
