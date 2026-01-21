# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Params do
  describe "#required" do
    it "adds a required parameter" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      expect(params.parameters.length).must_equal 1
      expect(params.parameters.first.required).must_equal true
    end

    it "sets the parameter name" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      expect(params.parameters.first.name).must_equal :city
    end

    it "sets the parameter type" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      expect(params.parameters.first.type).must_equal String
    end

    it "sets the description" do
      params = Riffer::Tools::Params.new
      params.required(:city, String, description: "The city name")
      expect(params.parameters.first.description).must_equal "The city name"
    end

    it "sets the enum" do
      params = Riffer::Tools::Params.new
      params.required(:unit, String, enum: ["celsius", "fahrenheit"])
      expect(params.parameters.first.enum).must_equal ["celsius", "fahrenheit"]
    end
  end

  describe "#optional" do
    it "adds an optional parameter" do
      params = Riffer::Tools::Params.new
      params.optional(:units, String)
      expect(params.parameters.length).must_equal 1
      expect(params.parameters.first.required).must_equal false
    end

    it "sets the default value" do
      params = Riffer::Tools::Params.new
      params.optional(:units, String, default: "celsius")
      expect(params.parameters.first.default).must_equal "celsius"
    end
  end

  describe "#validate" do
    it "returns validated arguments for valid input" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      result = params.validate({city: "Toronto"})
      expect(result).must_equal({city: "Toronto"})
    end

    it "raises ValidationError for missing required param" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
    end

    it "raises ValidationError for wrong type" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      error = expect { params.validate({city: 123}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city must be a string/)
    end

    it "raises ValidationError for enum violation" do
      params = Riffer::Tools::Params.new
      params.required(:unit, String, enum: ["celsius", "fahrenheit"])
      error = expect { params.validate({unit: "kelvin"}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/must be one of/)
    end

    it "applies default for missing optional param" do
      params = Riffer::Tools::Params.new
      params.optional(:units, String, default: "celsius")
      result = params.validate({})
      expect(result[:units]).must_equal "celsius"
    end

    it "uses provided value over default" do
      params = Riffer::Tools::Params.new
      params.optional(:units, String, default: "celsius")
      result = params.validate({units: "fahrenheit"})
      expect(result[:units]).must_equal "fahrenheit"
    end

    it "collects multiple errors" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      params.required(:country, String)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
      expect(error.message).must_match(/country is required/)
    end
  end

  describe "#to_json_schema" do
    it "returns object type" do
      params = Riffer::Tools::Params.new
      expect(params.to_json_schema[:type]).must_equal "object"
    end

    it "includes properties for each parameter" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      params.optional(:units, String)
      schema = params.to_json_schema
      expect(schema[:properties].keys).must_equal ["city", "units"]
    end

    it "includes required array" do
      params = Riffer::Tools::Params.new
      params.required(:city, String)
      params.optional(:units, String)
      schema = params.to_json_schema
      expect(schema[:required]).must_equal ["city"]
    end

    it "sets additionalProperties to false" do
      params = Riffer::Tools::Params.new
      expect(params.to_json_schema[:additionalProperties]).must_equal false
    end

    it "returns empty properties for no params" do
      params = Riffer::Tools::Params.new
      schema = params.to_json_schema
      expect(schema[:properties]).must_equal({})
      expect(schema[:required]).must_equal([])
    end
  end
end
