# frozen_string_literal: true

require "test_helper"

describe Riffer::StructuredOutput do
  describe "#initialize" do
    it "accepts a Hash shorthand" do
      so = Riffer::StructuredOutput.new(sentiment: String, score: Float)
      expect(so.params).must_be_instance_of Riffer::Params
    end

    it "accepts a Params instance" do
      params = Riffer::Params.new
      params.required(:sentiment, String)
      so = Riffer::StructuredOutput.new(params)
      expect(so.params).must_equal params
    end

    it "generates json_schema from Hash shorthand" do
      so = Riffer::StructuredOutput.new(sentiment: String)
      expect(so.json_schema[:type]).must_equal "object"
      expect(so.json_schema[:properties].keys).must_equal ["sentiment"]
    end

    it "generates json_schema from Params instance" do
      params = Riffer::Params.new
      params.required(:sentiment, String)
      so = Riffer::StructuredOutput.new(params)
      expect(so.json_schema[:type]).must_equal "object"
      expect(so.json_schema[:properties].keys).must_equal ["sentiment"]
    end
  end

  describe "#parse_and_validate" do
    it "returns successful result for valid JSON" do
      so = Riffer::StructuredOutput.new(sentiment: String, score: Float)
      result = so.parse_and_validate('{"sentiment":"positive","score":0.9}')
      expect(result.success?).must_equal true
    end

    it "returns validated object with symbolized keys" do
      so = Riffer::StructuredOutput.new(sentiment: String, score: Float)
      result = so.parse_and_validate('{"sentiment":"positive","score":0.9}')
      expect(result.object).must_equal({sentiment: "positive", score: 0.9})
    end

    it "returns failure result for invalid JSON" do
      so = Riffer::StructuredOutput.new(sentiment: String)
      result = so.parse_and_validate("not json")
      expect(result.failure?).must_equal true
    end

    it "includes JSON parse error message" do
      so = Riffer::StructuredOutput.new(sentiment: String)
      result = so.parse_and_validate("not json")
      expect(result.error).must_match(/JSON parse error/)
    end

    it "returns failure result for validation errors" do
      so = Riffer::StructuredOutput.new(sentiment: String, score: Float)
      result = so.parse_and_validate('{"sentiment":"positive"}')
      expect(result.failure?).must_equal true
    end

    it "includes validation error message" do
      so = Riffer::StructuredOutput.new(sentiment: String, score: Float)
      result = so.parse_and_validate('{"sentiment":"positive"}')
      expect(result.error).must_match(/Validation error/)
    end

    it "returns failure result for wrong types" do
      so = Riffer::StructuredOutput.new(sentiment: String)
      result = so.parse_and_validate('{"sentiment":123}')
      expect(result.failure?).must_equal true
    end
  end
end
