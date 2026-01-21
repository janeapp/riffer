# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Param do
  describe "#initialize" do
    it "sets the name as a symbol" do
      param = Riffer::Tools::Param.new(name: "city", type: String, required: true)
      expect(param.name).must_equal :city
    end

    it "sets the type" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.type).must_equal String
    end

    it "sets required flag" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.required).must_equal true
    end

    it "sets description" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true, description: "The city name")
      expect(param.description).must_equal "The city name"
    end

    it "sets enum" do
      param = Riffer::Tools::Param.new(name: :unit, type: String, required: true, enum: ["celsius", "fahrenheit"])
      expect(param.enum).must_equal ["celsius", "fahrenheit"]
    end

    it "sets default" do
      param = Riffer::Tools::Param.new(name: :unit, type: String, required: false, default: "celsius")
      expect(param.default).must_equal "celsius"
    end
  end

  describe "#valid_type?" do
    it "returns true for valid string type" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.valid_type?("Toronto")).must_equal true
    end

    it "returns false for invalid string type" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.valid_type?(123)).must_equal false
    end

    it "returns true for valid integer type" do
      param = Riffer::Tools::Param.new(name: :count, type: Integer, required: true)
      expect(param.valid_type?(42)).must_equal true
    end

    it "returns true for valid float type" do
      param = Riffer::Tools::Param.new(name: :amount, type: Float, required: true)
      expect(param.valid_type?(3.14)).must_equal true
    end

    it "returns true for true boolean value" do
      param = Riffer::Tools::Param.new(name: :enabled, type: TrueClass, required: true)
      expect(param.valid_type?(true)).must_equal true
    end

    it "returns true for false boolean value" do
      param = Riffer::Tools::Param.new(name: :enabled, type: TrueClass, required: true)
      expect(param.valid_type?(false)).must_equal true
    end

    it "returns true for nil on optional params" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: false)
      expect(param.valid_type?(nil)).must_equal true
    end

    it "returns true for valid array type" do
      param = Riffer::Tools::Param.new(name: :items, type: Array, required: true)
      expect(param.valid_type?([1, 2, 3])).must_equal true
    end

    it "returns true for valid hash type" do
      param = Riffer::Tools::Param.new(name: :data, type: Hash, required: true)
      expect(param.valid_type?({key: "value"})).must_equal true
    end
  end

  describe "#type_name" do
    it "returns 'string' for String" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.type_name).must_equal "string"
    end

    it "returns 'integer' for Integer" do
      param = Riffer::Tools::Param.new(name: :count, type: Integer, required: true)
      expect(param.type_name).must_equal "integer"
    end

    it "returns 'number' for Float" do
      param = Riffer::Tools::Param.new(name: :amount, type: Float, required: true)
      expect(param.type_name).must_equal "number"
    end

    it "returns 'boolean' for TrueClass" do
      param = Riffer::Tools::Param.new(name: :enabled, type: TrueClass, required: true)
      expect(param.type_name).must_equal "boolean"
    end

    it "returns 'array' for Array" do
      param = Riffer::Tools::Param.new(name: :items, type: Array, required: true)
      expect(param.type_name).must_equal "array"
    end

    it "returns 'object' for Hash" do
      param = Riffer::Tools::Param.new(name: :data, type: Hash, required: true)
      expect(param.type_name).must_equal "object"
    end
  end

  describe "#to_json_schema" do
    it "returns hash with type" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.to_json_schema[:type]).must_equal "string"
    end

    it "includes description when set" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true, description: "The city name")
      expect(param.to_json_schema[:description]).must_equal "The city name"
    end

    it "includes enum when set" do
      param = Riffer::Tools::Param.new(name: :unit, type: String, required: true, enum: ["celsius", "fahrenheit"])
      expect(param.to_json_schema[:enum]).must_equal ["celsius", "fahrenheit"]
    end

    it "excludes description when not set" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.to_json_schema.key?(:description)).must_equal false
    end

    it "excludes enum when not set" do
      param = Riffer::Tools::Param.new(name: :city, type: String, required: true)
      expect(param.to_json_schema.key?(:enum)).must_equal false
    end
  end
end
