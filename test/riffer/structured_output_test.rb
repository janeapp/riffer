# frozen_string_literal: true

require "test_helper"

describe Riffer::StructuredOutput do
  let(:sentiment_params) do
    params = Riffer::Params.new
    params.required(:sentiment, String)
    params
  end

  let(:sentiment_score_params) do
    params = Riffer::Params.new
    params.required(:sentiment, String)
    params.required(:score, Float)
    params
  end

  describe "#initialize" do
    it "accepts a Params instance" do
      so = Riffer::StructuredOutput.new(sentiment_params)
      expect(so.params).must_equal sentiment_params
    end

    it "generates json_schema from Params instance" do
      so = Riffer::StructuredOutput.new(sentiment_params)
      expect(so.json_schema[:type]).must_equal "object"
      expect(so.json_schema[:properties].keys).must_equal ["sentiment"]
    end
  end

  describe "#parse_and_validate" do
    it "returns successful result for valid JSON" do
      so = Riffer::StructuredOutput.new(sentiment_score_params)
      result = so.parse_and_validate('{"sentiment":"positive","score":0.9}')
      expect(result.success?).must_equal true
    end

    it "returns validated object with symbolized keys" do
      so = Riffer::StructuredOutput.new(sentiment_score_params)
      result = so.parse_and_validate('{"sentiment":"positive","score":0.9}')
      expect(result.object).must_equal({sentiment: "positive", score: 0.9})
    end

    it "returns failure result for invalid JSON" do
      so = Riffer::StructuredOutput.new(sentiment_params)
      result = so.parse_and_validate("not json")
      expect(result.failure?).must_equal true
    end

    it "includes JSON parse error message" do
      so = Riffer::StructuredOutput.new(sentiment_params)
      result = so.parse_and_validate("not json")
      expect(result.error).must_match(/JSON parse error/)
    end

    it "returns failure result for validation errors" do
      so = Riffer::StructuredOutput.new(sentiment_score_params)
      result = so.parse_and_validate('{"sentiment":"positive"}')
      expect(result.failure?).must_equal true
    end

    it "includes validation error message" do
      so = Riffer::StructuredOutput.new(sentiment_score_params)
      result = so.parse_and_validate('{"sentiment":"positive"}')
      expect(result.error).must_match(/Validation error/)
    end

    it "returns failure result for wrong types" do
      so = Riffer::StructuredOutput.new(sentiment_params)
      result = so.parse_and_validate('{"sentiment":123}')
      expect(result.failure?).must_equal true
    end

    describe "with null optional fields" do
      let(:nested_params) do
        params = Riffer::Params.new
        params.required(:name, String)
        params.required(:address, Hash) do
          required :city, String
          optional :zip, String
        end
        params
      end

      let(:array_of_objects_params) do
        params = Riffer::Params.new
        params.required(:items, Array) do
          required :sku, String
          optional :notes, String
        end
        params
      end

      it "accepts null for a top-level optional field" do
        params = Riffer::Params.new
        params.required(:name, String)
        params.optional(:age, Integer)
        so = Riffer::StructuredOutput.new(params)
        result = so.parse_and_validate('{"name":"John","age":null}')
        expect(result.success?).must_equal true
        expect(result.object[:name]).must_equal "John"
        expect(result.object[:age]).must_be_nil
      end

      it "accepts null for a nested optional field" do
        so = Riffer::StructuredOutput.new(nested_params)
        result = so.parse_and_validate('{"name":"John","address":{"city":"Toronto","zip":null}}')
        expect(result.success?).must_equal true
        expect(result.object[:address][:city]).must_equal "Toronto"
        expect(result.object[:address][:zip]).must_be_nil
      end

      it "accepts null for an optional field inside array of objects" do
        so = Riffer::StructuredOutput.new(array_of_objects_params)
        result = so.parse_and_validate('{"items":[{"sku":"ABC","notes":null}]}')
        expect(result.success?).must_equal true
        expect(result.object[:items].first[:sku]).must_equal "ABC"
        expect(result.object[:items].first[:notes]).must_be_nil
      end

      it "accepts absent optional fields the same as null" do
        params = Riffer::Params.new
        params.required(:name, String)
        params.optional(:age, Integer)
        so = Riffer::StructuredOutput.new(params)
        result = so.parse_and_validate('{"name":"John"}')
        expect(result.success?).must_equal true
        expect(result.object[:age]).must_be_nil
      end

      it "still rejects null for required fields" do
        params = Riffer::Params.new
        params.required(:name, String)
        params.optional(:age, Integer)
        so = Riffer::StructuredOutput.new(params)
        result = so.parse_and_validate('{"name":null,"age":25}')
        expect(result.failure?).must_equal true
        expect(result.error).must_match(/name is required/)
      end
    end
  end
end
