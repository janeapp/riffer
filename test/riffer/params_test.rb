# frozen_string_literal: true

require "test_helper"

describe Riffer::Params do
  describe "#required" do
    it "adds a parameter" do
      params = Riffer::Params.new
      params.required(:city, String)
      expect(params.parameters.length).must_equal 1
    end

    it "marks the parameter as required" do
      params = Riffer::Params.new
      params.required(:city, String)
      expect(params.parameters.first.required).must_equal true
    end

    it "sets the parameter name" do
      params = Riffer::Params.new
      params.required(:city, String)
      expect(params.parameters.first.name).must_equal :city
    end

    it "sets the parameter type" do
      params = Riffer::Params.new
      params.required(:city, String)
      expect(params.parameters.first.type).must_equal String
    end

    it "sets the description" do
      params = Riffer::Params.new
      params.required(:city, String, description: "The city name")
      expect(params.parameters.first.description).must_equal "The city name"
    end

    it "sets the enum" do
      params = Riffer::Params.new
      params.required(:unit, String, enum: ["celsius", "fahrenheit"])
      expect(params.parameters.first.enum).must_equal ["celsius", "fahrenheit"]
    end
  end

  describe "#optional" do
    it "adds a parameter" do
      params = Riffer::Params.new
      params.optional(:units, String)
      expect(params.parameters.length).must_equal 1
    end

    it "marks the parameter as not required" do
      params = Riffer::Params.new
      params.optional(:units, String)
      expect(params.parameters.first.required).must_equal false
    end

    it "sets the default value" do
      params = Riffer::Params.new
      params.optional(:units, String, default: "celsius")
      expect(params.parameters.first.default).must_equal "celsius"
    end
  end

  describe "#validate" do
    it "returns validated arguments for valid input" do
      params = Riffer::Params.new
      params.required(:city, String)
      result = params.validate({city: "Toronto"})
      expect(result).must_equal({city: "Toronto"})
    end

    it "raises ValidationError for missing required param" do
      params = Riffer::Params.new
      params.required(:city, String)
      expect { params.validate({}) }.must_raise(Riffer::ValidationError)
    end

    it "includes param name in missing required error" do
      params = Riffer::Params.new
      params.required(:city, String)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
    end

    it "raises ValidationError for wrong type" do
      params = Riffer::Params.new
      params.required(:city, String)
      expect { params.validate({city: 123}) }.must_raise(Riffer::ValidationError)
    end

    it "includes param name in wrong type error" do
      params = Riffer::Params.new
      params.required(:city, String)
      error = expect { params.validate({city: 123}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city must be a string/)
    end

    it "raises ValidationError for enum violation" do
      params = Riffer::Params.new
      params.required(:unit, String, enum: ["celsius", "fahrenheit"])
      expect { params.validate({unit: "kelvin"}) }.must_raise(Riffer::ValidationError)
    end

    it "includes allowed values in enum violation error" do
      params = Riffer::Params.new
      params.required(:unit, String, enum: ["celsius", "fahrenheit"])
      error = expect { params.validate({unit: "kelvin"}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/must be one of/)
    end

    it "applies default for missing optional param" do
      params = Riffer::Params.new
      params.optional(:units, String, default: "celsius")
      result = params.validate({})
      expect(result[:units]).must_equal "celsius"
    end

    it "uses provided value over default" do
      params = Riffer::Params.new
      params.optional(:units, String, default: "celsius")
      result = params.validate({units: "fahrenheit"})
      expect(result[:units]).must_equal "fahrenheit"
    end

    it "includes first missing param in multiple errors" do
      params = Riffer::Params.new
      params.required(:city, String)
      params.required(:country, String)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
    end

    it "includes second missing param in multiple errors" do
      params = Riffer::Params.new
      params.required(:city, String)
      params.required(:country, String)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/country is required/)
    end
  end

  describe "nested DSL" do
    it "supports of: keyword for typed arrays" do
      params = Riffer::Params.new
      params.required(:tags, Array, of: String)
      schema = params.to_json_schema
      expect(schema[:properties]["tags"][:items]).must_equal({type: "string"})
    end

    it "supports block on Hash for nested objects" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :street, String
        required :city, String
        optional :zip, String
      end
      schema = params.to_json_schema
      address = schema[:properties]["address"]
      expect(address[:type]).must_equal "object"
      expect(address[:properties].keys).must_equal ["street", "city", "zip"]
      expect(address[:required]).must_equal ["street", "city"]
      expect(address[:additionalProperties]).must_equal false
    end

    it "supports block on Array for array of objects" do
      params = Riffer::Params.new
      params.required(:line_items, Array) do
        required :product, String
        required :quantity, Integer
        optional :note, String
      end
      schema = params.to_json_schema
      items = schema[:properties]["line_items"][:items]
      expect(items[:type]).must_equal "object"
      expect(items[:properties].keys).must_equal ["product", "quantity", "note"]
      expect(items[:required]).must_equal ["product", "quantity"]
    end

    it "raises ArgumentError when both of: and block are given" do
      params = Riffer::Params.new
      expect {
        params.required(:tags, Array, of: String) do
          required :name, String
        end
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is Hash" do
      params = Riffer::Params.new
      expect {
        params.required(:items, Array, of: Hash)
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is Array" do
      params = Riffer::Params.new
      expect {
        params.required(:items, Array, of: Array)
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is a non-JSON-Schema type" do
      params = Riffer::Params.new
      expect {
        params.required(:items, Array, of: Regexp)
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is used on Hash type" do
      params = Riffer::Params.new
      expect {
        params.required(:data, Hash, of: String)
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is used on String type" do
      params = Riffer::Params.new
      expect {
        params.required(:name, String, of: String)
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when block is used on String type" do
      params = Riffer::Params.new
      expect {
        params.required(:name, String) { required :foo, String }
      }.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when block is used on Integer type" do
      params = Riffer::Params.new
      expect {
        params.optional(:count, Integer) { required :foo, String }
      }.must_raise(Riffer::ArgumentError)
    end

    it "supports deep nesting with blocks within blocks" do
      params = Riffer::Params.new
      params.required(:orders, Array) do
        required :shipping, Hash do
          required :address, Hash do
            required :street, String
          end
        end
      end
      schema = params.to_json_schema
      street = schema.dig(
        :properties, "orders",
        :items, :properties, "shipping",
        :properties, "address",
        :properties, "street"
      )
      expect(street).must_equal({type: "string"})
    end
  end

  describe "#validate with nested params" do
    it "validates typed array accepts valid items" do
      params = Riffer::Params.new
      params.required(:tags, Array, of: String)
      result = params.validate({tags: ["a", "b"]})
      expect(result[:tags]).must_equal ["a", "b"]
    end

    it "validates typed array rejects invalid items" do
      params = Riffer::Params.new
      params.required(:tags, Array, of: String)
      error = expect { params.validate({tags: ["a", 123]}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/tags\[1\] must be a string/)
    end

    it "validates nested Hash recursively with dot-path errors" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :street, String
        required :city, String
      end
      error = expect {
        params.validate({address: {street: "123 Main"}})
      }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/address\.city is required/)
    end

    it "validates array of objects with indexed errors" do
      params = Riffer::Params.new
      params.required(:items, Array) do
        required :name, String
        required :qty, Integer
      end
      error = expect {
        params.validate({items: [{name: "A", qty: 1}, {name: "B"}]})
      }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/items\[1\]\.qty is required/)
    end

    it "validates deep nesting with correct dot-path errors" do
      params = Riffer::Params.new
      params.required(:orders, Array) do
        required :shipping, Hash do
          required :address, Hash do
            required :street, String
          end
        end
      end
      error = expect {
        params.validate({orders: [{shipping: {address: {}}}]})
      }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/orders\[0\]\.shipping\.address\.street is required/)
    end

    it "accepts valid nested Hash" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :city, String
      end
      result = params.validate({address: {city: "Toronto"}})
      expect(result[:address]).must_equal({city: "Toronto"})
    end

    it "deep symbolizes string keys in nested Hash" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :city, String
      end
      result = params.validate({address: {"city" => "Toronto"}})
      expect(result[:address]).must_equal({city: "Toronto"})
    end

    it "accepts valid array of objects" do
      params = Riffer::Params.new
      params.required(:items, Array) do
        required :name, String
      end
      result = params.validate({items: [{name: "A"}, {name: "B"}]})
      expect(result[:items]).must_equal [{name: "A"}, {name: "B"}]
    end

    it "deep symbolizes string keys in array of objects" do
      params = Riffer::Params.new
      params.required(:items, Array) do
        required :name, String
      end
      result = params.validate({items: [{"name" => "A"}, {"name" => "B"}]})
      expect(result[:items]).must_equal [{name: "A"}, {name: "B"}]
    end

    it "deep symbolizes keys in deeply nested structures" do
      params = Riffer::Params.new
      params.required(:order, Hash) do
        required :shipping, Hash do
          required :city, String
        end
      end
      result = params.validate({order: {"shipping" => {"city" => "Toronto"}}})
      expect(result[:order]).must_equal({shipping: {city: "Toronto"}})
    end
  end

  describe "#to_json_schema" do
    it "returns object type" do
      params = Riffer::Params.new
      expect(params.to_json_schema[:type]).must_equal "object"
    end

    it "includes properties for each parameter" do
      params = Riffer::Params.new
      params.required(:city, String)
      params.optional(:units, String)
      schema = params.to_json_schema
      expect(schema[:properties].keys).must_equal ["city", "units"]
    end

    it "includes required array" do
      params = Riffer::Params.new
      params.required(:city, String)
      params.optional(:units, String)
      schema = params.to_json_schema
      expect(schema[:required]).must_equal ["city"]
    end

    it "sets additionalProperties to false" do
      params = Riffer::Params.new
      expect(params.to_json_schema[:additionalProperties]).must_equal false
    end

    it "returns empty properties for no params" do
      params = Riffer::Params.new
      schema = params.to_json_schema
      expect(schema[:properties]).must_equal({})
    end

    it "returns empty required array for no params" do
      params = Riffer::Params.new
      schema = params.to_json_schema
      expect(schema[:required]).must_equal([])
    end
  end

  describe "#to_json_schema(strict: true)" do
    it "makes optional properties nullable and required" do
      params = Riffer::Params.new
      params.required(:name, String)
      params.optional(:age, Integer)
      schema = params.to_json_schema(strict: true)

      expect(schema[:required]).must_include "name"
      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["name"][:type]).must_equal "string"
      expect(schema[:properties]["age"][:type]).must_equal ["integer", "null"]
    end

    it "recurses into nested objects" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :city, String
        optional :zip, String
      end
      schema = params.to_json_schema(strict: true)
      address = schema[:properties]["address"]

      expect(address[:required]).must_include "city"
      expect(address[:required]).must_include "zip"
      expect(address[:properties]["city"][:type]).must_equal "string"
      expect(address[:properties]["zip"][:type]).must_equal ["string", "null"]
    end

    it "recurses into array items" do
      params = Riffer::Params.new
      params.required(:items, Array) do
        required :name, String
        optional :note, String
      end
      schema = params.to_json_schema(strict: true)
      items_schema = schema[:properties]["items"][:items]

      expect(items_schema[:required]).must_include "name"
      expect(items_schema[:required]).must_include "note"
      expect(items_schema[:properties]["name"][:type]).must_equal "string"
      expect(items_schema[:properties]["note"][:type]).must_equal ["string", "null"]
    end

    it "keeps required properties non-nullable" do
      params = Riffer::Params.new
      params.required(:name, String)
      schema = params.to_json_schema(strict: true)

      expect(schema[:properties]["name"][:type]).must_equal "string"
    end
  end
end
