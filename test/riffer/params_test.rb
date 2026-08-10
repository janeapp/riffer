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
      params.required(:unit, String, enum: %w[celsius fahrenheit])

      expect(params.parameters.first.enum).must_equal %w[celsius fahrenheit]
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
      result = params.validate({ city: "Toronto" })

      expect(result).must_equal({ city: "Toronto" })
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

      expect { params.validate({ city: 123 }) }.must_raise(Riffer::ValidationError)
    end

    it "includes param name in wrong type error" do
      params = Riffer::Params.new
      params.required(:city, String)
      error = expect { params.validate({ city: 123 }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city must be a string/)
    end

    it "raises ValidationError for enum violation" do
      params = Riffer::Params.new
      params.required(:unit, String, enum: %w[celsius fahrenheit])

      expect { params.validate({ unit: "kelvin" }) }.must_raise(Riffer::ValidationError)
    end

    it "includes allowed values in enum violation error" do
      params = Riffer::Params.new
      params.required(:unit, String, enum: %w[celsius fahrenheit])
      error = expect { params.validate({ unit: "kelvin" }) }.must_raise(Riffer::ValidationError)
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
      result = params.validate({ units: "fahrenheit" })

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

      expect(schema[:properties]["tags"][:items]).must_equal({ type: "string" })
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
      expect(address[:properties].keys).must_equal %w[street city zip]
      expect(address[:required]).must_equal %w[street city]
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
      expect(items[:properties].keys).must_equal %w[product quantity note]
      expect(items[:required]).must_equal %w[product quantity]
    end

    it "raises ArgumentError when both of: and block are given" do
      params = Riffer::Params.new

      expect do
        params.required(:tags, Array, of: String) do
          required :name, String
        end
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is Hash" do
      params = Riffer::Params.new

      expect do
        params.required(:items, Array, of: Hash)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is Array" do
      params = Riffer::Params.new

      expect do
        params.required(:items, Array, of: Array)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is a non-JSON-Schema type" do
      params = Riffer::Params.new

      expect do
        params.required(:items, Array, of: Regexp)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is used on Hash type" do
      params = Riffer::Params.new

      expect do
        params.required(:data, Hash, of: String)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is used on String type" do
      params = Riffer::Params.new

      expect do
        params.required(:name, String, of: String)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when block is used on String type" do
      params = Riffer::Params.new

      expect do
        params.required(:name, String) { required :foo, String }
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when block is used on Integer type" do
      params = Riffer::Params.new

      expect do
        params.optional(:count, Integer) { required :foo, String }
      end.must_raise(Riffer::ArgumentError)
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
        :properties, "street",
      )

      expect(street).must_equal({ type: "string" })
    end
  end

  describe "#validate with nested params" do
    it "validates typed array accepts valid items" do
      params = Riffer::Params.new
      params.required(:tags, Array, of: String)
      result = params.validate({ tags: %w[a b] })

      expect(result[:tags]).must_equal %w[a b]
    end

    it "validates typed array rejects invalid items" do
      params = Riffer::Params.new
      params.required(:tags, Array, of: String)
      error = expect { params.validate({ tags: ["a", 123] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/tags\[1\] must be a string/)
    end

    it "validates nested Hash recursively with dot-path errors" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :street, String
        required :city, String
      end
      error = expect do
        params.validate({ address: { street: "123 Main" } })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/address\.city is required/)
    end

    it "validates array of objects with indexed errors" do
      params = Riffer::Params.new
      params.required(:items, Array) do
        required :name, String
        required :qty, Integer
      end
      error = expect do
        params.validate({ items: [{ name: "A", qty: 1 }, { name: "B" }] })
      end.must_raise(Riffer::ValidationError)
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
      error = expect do
        params.validate({ orders: [{ shipping: { address: {} } }] })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/orders\[0\]\.shipping\.address\.street is required/)
    end

    it "accepts valid nested Hash" do
      params = Riffer::Params.new
      params.required(:address, Hash) do
        required :city, String
      end
      result = params.validate({ address: { city: "Toronto" } })

      expect(result[:address]).must_equal({ city: "Toronto" })
    end

    it "accepts valid array of objects" do
      params = Riffer::Params.new
      params.required(:items, Array) do
        required :name, String
      end
      result = params.validate({ items: [{ name: "A" }, { name: "B" }] })

      expect(result[:items]).must_equal [{ name: "A" }, { name: "B" }]
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

      expect(schema[:properties].keys).must_equal %w[city units]
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
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
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
      expect(address[:properties]["zip"][:type]).must_equal %w[string null]
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
      expect(items_schema[:properties]["note"][:type]).must_equal %w[string null]
    end

    it "keeps required properties non-nullable" do
      params = Riffer::Params.new
      params.required(:name, String)
      schema = params.to_json_schema(strict: true)

      expect(schema[:properties]["name"][:type]).must_equal "string"
    end

    it "emits default in non-strict mode" do
      params = Riffer::Params.new
      params.optional(:units, String, default: "celsius")
      schema = params.to_json_schema(strict: false)

      expect(schema[:properties]["units"][:default]).must_equal "celsius"
    end

    it "omits default in strict mode" do
      params = Riffer::Params.new
      params.optional(:units, String, default: "celsius")
      schema = params.to_json_schema(strict: true)

      expect(schema[:properties]["units"].key?(:default)).must_equal false
    end

    it "omits default when none is set" do
      params = Riffer::Params.new
      params.optional(:units, String)
      schema = params.to_json_schema(strict: false)

      expect(schema[:properties]["units"].key?(:default)).must_equal false
    end
  end

  describe ".from_json_schema" do
    it "reconstructs a simple required parameter" do
      params = Riffer::Params.from_json_schema({
                                                 type: "object",
                                                 properties: { "city" => { type: "string", description: "city name" } },
                                                 required: ["city"],
                                                 additionalProperties: false,
                                               })
      param = params.parameters.first

      expect(param.name).must_equal :city
      expect(param.type).must_equal String
      expect(param.required).must_equal true
      expect(param.description).must_equal "city name"
    end

    it "marks properties absent from required as optional" do
      params = Riffer::Params.from_json_schema({
                                                 type: "object",
                                                 properties: { "note" => { type: "string" } },
                                                 required: [],
                                                 additionalProperties: false,
                                               })

      expect(params.parameters.first.required).must_equal false
    end

    it "reconstructs enum and default" do
      params = Riffer::Params.from_json_schema({
                                                 type: "object",
                                                 properties: { "units" => { type: "string",
                                                                            enum: %w[celsius fahrenheit], default: "celsius", } },
                                                 required: [],
                                                 additionalProperties: false,
                                               })
      param = params.parameters.first

      expect(param.enum).must_equal %w[celsius fahrenheit]
      expect(param.default).must_equal "celsius"
    end

    it "reconstructs each JSON Schema type to its Ruby type" do
      params = Riffer::Params.from_json_schema({
                                                 type: "object",
                                                 properties: {
                                                   "s" => { type: "string" }, "i" => { type: "integer" },
                                                   "n" => { type: "number" }, "b" => { type: "boolean" },
                                                 },
                                                 required: [],
                                                 additionalProperties: false,
                                               })
      types = params.parameters.to_h { |p| [p.name, p.type] }

      expect(types).must_equal({ s: String, i: Integer, n: Float, b: Riffer::Params::Boolean })
    end

    it "reconstructs typed arrays" do
      params = Riffer::Params.from_json_schema({
                                                 type: "object",
                                                 properties: { "tags" => { type: "array",
                                                                           items: { type: "integer" }, } },
                                                 required: ["tags"],
                                                 additionalProperties: false,
                                               })

      expect(params.parameters.first.item_type).must_equal Integer
    end

    it "reconstructs nested object params" do
      params = Riffer::Params.from_json_schema({
                                                 type: "object",
                                                 properties: {
                                                   "address" => {
                                                     type: "object",
                                                     properties: { "street" => { type: "string" } },
                                                     required: ["street"],
                                                     additionalProperties: false,
                                                   },
                                                 },
                                                 required: ["address"],
                                                 additionalProperties: false,
                                               })
      nested = params.parameters.first.nested_params

      expect(nested).must_be_instance_of Riffer::Params
      expect(nested.parameters.first.name).must_equal :street
    end

    it "raises on an unsupported JSON Schema type" do
      expect do
        Riffer::Params.from_json_schema({
                                          type: "object",
                                          properties: { "x" => { type: "anyOf-thing" } },
                                          required: [],
                                          additionalProperties: false,
                                        })
      end.must_raise Riffer::ArgumentError
    end

    it "round-trips losslessly with to_json_schema(strict: false)" do
      params = Riffer::Params.new
      params.required(:city, String, description: "city name")
      params.optional(:units, String, default: "celsius", enum: %w[celsius fahrenheit])
      params.required(:tags, Array, of: Integer)
      params.required(:address, Hash) do
        required :street, String
        optional :zip, String
      end
      params.required(:contacts, Array) do
        required :name, String
      end
      schema = params.to_json_schema(strict: false)

      rebuilt = Riffer::Params.from_json_schema(schema)

      expect(rebuilt.to_json_schema(strict: false)).must_equal schema
    end

    it "round-trips through JSON with symbolized keys" do
      params = Riffer::Params.new
      params.optional(:units, String, default: "celsius")
      schema = params.to_json_schema(strict: false)
      wire = JSON.parse(JSON.generate(schema), symbolize_names: true)

      rebuilt = Riffer::Params.from_json_schema(wire)

      expect(rebuilt.to_json_schema(strict: false)).must_equal schema
    end

    it "reconstructs a Params that still validates and fills defaults" do
      schema = {
        type: "object",
        properties: {
          "answer" => { type: "string" },
          "score" => { type: "number", default: 0.0 },
        },
        required: ["answer"],
        additionalProperties: false,
      }
      rebuilt = Riffer::Params.from_json_schema(schema)

      expect(rebuilt.validate({ answer: "yes" })).must_equal({ answer: "yes", score: 0.0 })
    end
  end
end
