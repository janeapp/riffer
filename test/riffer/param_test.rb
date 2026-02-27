# frozen_string_literal: true

require "test_helper"

describe Riffer::Param do
  describe "#initialize" do
    it "sets the name as a symbol" do
      param = Riffer::Param.new(name: "city", type: String, required: true)
      expect(param.name).must_equal :city
    end

    it "sets the type" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.type).must_equal String
    end

    it "sets required flag" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.required).must_equal true
    end

    it "sets description" do
      param = Riffer::Param.new(name: :city, type: String, required: true, description: "The city name")
      expect(param.description).must_equal "The city name"
    end

    it "sets enum" do
      param = Riffer::Param.new(name: :unit, type: String, required: true, enum: ["celsius", "fahrenheit"])
      expect(param.enum).must_equal ["celsius", "fahrenheit"]
    end

    it "sets default" do
      param = Riffer::Param.new(name: :unit, type: String, required: false, default: "celsius")
      expect(param.default).must_equal "celsius"
    end
  end

  describe "#valid_type?" do
    it "returns true for valid string type" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.valid_type?("Toronto")).must_equal true
    end

    it "returns false for invalid string type" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.valid_type?(123)).must_equal false
    end

    it "returns true for valid integer type" do
      param = Riffer::Param.new(name: :count, type: Integer, required: true)
      expect(param.valid_type?(42)).must_equal true
    end

    it "returns true for valid float type" do
      param = Riffer::Param.new(name: :amount, type: Float, required: true)
      expect(param.valid_type?(3.14)).must_equal true
    end

    it "returns true for true boolean value" do
      param = Riffer::Param.new(name: :enabled, type: TrueClass, required: true)
      expect(param.valid_type?(true)).must_equal true
    end

    it "returns true for false boolean value" do
      param = Riffer::Param.new(name: :enabled, type: TrueClass, required: true)
      expect(param.valid_type?(false)).must_equal true
    end

    it "returns true for true with Riffer::Boolean type" do
      param = Riffer::Param.new(name: :enabled, type: Riffer::Boolean, required: true)
      expect(param.valid_type?(true)).must_equal true
    end

    it "returns true for false with Riffer::Boolean type" do
      param = Riffer::Param.new(name: :enabled, type: Riffer::Boolean, required: true)
      expect(param.valid_type?(false)).must_equal true
    end

    it "returns false for non-boolean with Riffer::Boolean type" do
      param = Riffer::Param.new(name: :enabled, type: Riffer::Boolean, required: true)
      expect(param.valid_type?("true")).must_equal false
    end

    it "returns true for nil on optional params" do
      param = Riffer::Param.new(name: :city, type: String, required: false)
      expect(param.valid_type?(nil)).must_equal true
    end

    it "returns true for valid array type" do
      param = Riffer::Param.new(name: :items, type: Array, required: true)
      expect(param.valid_type?([1, 2, 3])).must_equal true
    end

    it "returns true for valid hash type" do
      param = Riffer::Param.new(name: :data, type: Hash, required: true)
      expect(param.valid_type?({key: "value"})).must_equal true
    end
  end

  describe "#type_name" do
    it "returns 'string' for String" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.type_name).must_equal "string"
    end

    it "returns 'integer' for Integer" do
      param = Riffer::Param.new(name: :count, type: Integer, required: true)
      expect(param.type_name).must_equal "integer"
    end

    it "returns 'number' for Float" do
      param = Riffer::Param.new(name: :amount, type: Float, required: true)
      expect(param.type_name).must_equal "number"
    end

    it "returns 'boolean' for TrueClass" do
      param = Riffer::Param.new(name: :enabled, type: TrueClass, required: true)
      expect(param.type_name).must_equal "boolean"
    end

    it "returns 'boolean' for Riffer::Boolean" do
      param = Riffer::Param.new(name: :enabled, type: Riffer::Boolean, required: true)
      expect(param.type_name).must_equal "boolean"
    end

    it "returns 'array' for Array" do
      param = Riffer::Param.new(name: :items, type: Array, required: true)
      expect(param.type_name).must_equal "array"
    end

    it "returns 'object' for Hash" do
      param = Riffer::Param.new(name: :data, type: Hash, required: true)
      expect(param.type_name).must_equal "object"
    end
  end

  describe "#to_json_schema" do
    it "returns hash with type" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.to_json_schema[:type]).must_equal "string"
    end

    it "includes description when set" do
      param = Riffer::Param.new(name: :city, type: String, required: true, description: "The city name")
      expect(param.to_json_schema[:description]).must_equal "The city name"
    end

    it "includes enum when set" do
      param = Riffer::Param.new(name: :unit, type: String, required: true, enum: ["celsius", "fahrenheit"])
      expect(param.to_json_schema[:enum]).must_equal ["celsius", "fahrenheit"]
    end

    it "excludes description when not set" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.to_json_schema.key?(:description)).must_equal false
    end

    it "excludes enum when not set" do
      param = Riffer::Param.new(name: :city, type: String, required: true)
      expect(param.to_json_schema.key?(:enum)).must_equal false
    end

    it "includes items with type for Array with item_type" do
      param = Riffer::Param.new(name: :tags, type: Array, required: true, item_type: String)
      schema = param.to_json_schema
      expect(schema[:type]).must_equal "array"
      expect(schema[:items]).must_equal({type: "string"})
    end

    it "includes nested object schema for Hash with nested_params" do
      nested = Riffer::Params.new
      nested.required(:street, String)
      nested.optional(:zip, String)
      param = Riffer::Param.new(name: :address, type: Hash, required: true, nested_params: nested)
      schema = param.to_json_schema
      expect(schema[:type]).must_equal "object"
      expect(schema[:properties]).must_equal(
        "street" => {type: "string"},
        "zip" => {type: "string"}
      )
      expect(schema[:required]).must_equal ["street"]
      expect(schema[:additionalProperties]).must_equal false
    end

    it "includes items with object schema for Array with nested_params" do
      nested = Riffer::Params.new
      nested.required(:product, String)
      nested.required(:quantity, Integer)
      param = Riffer::Param.new(name: :line_items, type: Array, required: true, nested_params: nested)
      schema = param.to_json_schema
      expect(schema[:type]).must_equal "array"
      expect(schema[:items][:type]).must_equal "object"
      expect(schema[:items][:properties].keys).must_equal ["product", "quantity"]
      expect(schema[:items][:required]).must_equal ["product", "quantity"]
    end
  end
end
