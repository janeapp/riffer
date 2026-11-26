# frozen_string_literal: true

require "test_helper"

describe Riffer::Params do
  describe "Ruby class types" do
    after { reset_riffer_config! }

    it "raises the param_class_types deprecation in :raise mode" do
      error = expect { Riffer::Params.new.required(:city, String) }.must_raise Riffer::DeprecationError

      expect(error.message).must_include(
        "String as a param type is deprecated and will be removed in a future version, " \
        "not before 1 December 2026; use :string.",
      )
    end

    it "reports the line that declares the param" do
      events = []
      Riffer.config.deprecations = ->(event) { events << event }
      line = __LINE__ + 1
      Riffer::Params.new.optional(:city, String)

      expect(events.map { |event| [event.id, event.location] }).must_equal [[:param_class_types, "#{__FILE__}:#{line}"]]
    end

    it "resolves each class to its type symbol" do
      params = Riffer::Params.new
      classes = [String, Integer, Float, Riffer::Params::Boolean, TrueClass, FalseClass, Array, Hash]
      allow_deprecations { classes.each.with_index { |type, i| params.required(:"param_#{i}", type) } }

      expect(params.parameters.map(&:type)).must_equal %i[string integer number boolean boolean boolean array object]
    end

    it "resolves classes passed to of: and variant" do
      params = Riffer::Params.new
      allow_deprecations do
        params.required(:tags, Array, of: [String])
        params.required(:quantity, Riffer::Params::AnyOf) do
          variant Integer
          variant String
        end
      end
      tags, quantity = params.parameters

      expect([tags.type, tags.item_type, tags.dimensions]).must_equal [:array, :string, 2]
      expect([quantity.type, *quantity.variants.map(&:type)]).must_equal %i[any_of integer string]
    end

    it "reports nothing for symbol types or params read from JSON Schema" do
      events = []
      Riffer.config.deprecations = ->(event) { events << event }
      params = Riffer::Params.new
      params.required(:tags, :array, of: [:string])
      params.optional(:quantity, :any_of) do
        variant :integer
        variant :string
      end
      Riffer::Params.from_json_schema(params.to_json_schema)

      expect(events).must_be_empty
    end

    it "raises ArgumentError for an unsupported type" do
      [Symbol, :date, "string"].each do |type|
        error = expect { Riffer::Params.new.required(:on, type) }.must_raise Riffer::ArgumentError
        expect(error.message).must_equal(
          "type must be one of :string, :integer, :number, :boolean, :array, :object, :any_of, got #{type.inspect}",
        )
      end
    end
  end

  describe "#required" do
    it "adds a parameter" do
      params = Riffer::Params.new
      params.required(:city, :string)

      expect(params.parameters.length).must_equal 1
    end

    it "marks the parameter as required" do
      params = Riffer::Params.new
      params.required(:city, :string)

      expect(params.parameters.first.required).must_equal true
    end

    it "sets the parameter name" do
      params = Riffer::Params.new
      params.required(:city, :string)

      expect(params.parameters.first.name).must_equal :city
    end

    it "sets the parameter type" do
      params = Riffer::Params.new
      params.required(:city, :string)

      expect(params.parameters.first.type).must_equal :string
    end

    it "sets the description" do
      params = Riffer::Params.new
      params.required(:city, :string, description: "The city name")

      expect(params.parameters.first.description).must_equal "The city name"
    end

    it "sets the enum" do
      params = Riffer::Params.new
      params.required(:unit, :string, enum: %w[celsius fahrenheit])

      expect(params.parameters.first.enum).must_equal %w[celsius fahrenheit]
    end
  end

  describe "#optional" do
    it "adds a parameter" do
      params = Riffer::Params.new
      params.optional(:units, :string)

      expect(params.parameters.length).must_equal 1
    end

    it "marks the parameter as not required" do
      params = Riffer::Params.new
      params.optional(:units, :string)

      expect(params.parameters.first.required).must_equal false
    end

    it "sets the default value" do
      params = Riffer::Params.new
      params.optional(:units, :string, default: "celsius")

      expect(params.parameters.first.default).must_equal "celsius"
    end
  end

  describe "#validate" do
    it "returns validated arguments for valid input" do
      params = Riffer::Params.new
      params.required(:city, :string)
      result = params.validate({ city: "Toronto" })

      expect(result).must_equal({ city: "Toronto" })
    end

    it "raises ValidationError for missing required param" do
      params = Riffer::Params.new
      params.required(:city, :string)

      expect { params.validate({}) }.must_raise(Riffer::ValidationError)
    end

    it "includes param name in missing required error" do
      params = Riffer::Params.new
      params.required(:city, :string)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
    end

    it "raises ValidationError for wrong type" do
      params = Riffer::Params.new
      params.required(:city, :string)

      expect { params.validate({ city: 123 }) }.must_raise(Riffer::ValidationError)
    end

    it "includes param name in wrong type error" do
      params = Riffer::Params.new
      params.required(:city, :string)
      error = expect { params.validate({ city: 123 }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city must be a string/)
    end

    it "raises ValidationError for enum violation" do
      params = Riffer::Params.new
      params.required(:unit, :string, enum: %w[celsius fahrenheit])

      expect { params.validate({ unit: "kelvin" }) }.must_raise(Riffer::ValidationError)
    end

    it "includes allowed values in enum violation error" do
      params = Riffer::Params.new
      params.required(:unit, :string, enum: %w[celsius fahrenheit])
      error = expect { params.validate({ unit: "kelvin" }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/must be one of/)
    end

    it "applies default for missing optional param" do
      params = Riffer::Params.new
      params.optional(:units, :string, default: "celsius")
      result = params.validate({})

      expect(result[:units]).must_equal "celsius"
    end

    it "uses provided value over default" do
      params = Riffer::Params.new
      params.optional(:units, :string, default: "celsius")
      result = params.validate({ units: "fahrenheit" })

      expect(result[:units]).must_equal "fahrenheit"
    end

    it "includes first missing param in multiple errors" do
      params = Riffer::Params.new
      params.required(:city, :string)
      params.required(:country, :string)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
    end

    it "includes second missing param in multiple errors" do
      params = Riffer::Params.new
      params.required(:city, :string)
      params.required(:country, :string)
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/country is required/)
    end
  end

  describe "nested DSL" do
    it "supports of: keyword for typed arrays" do
      params = Riffer::Params.new
      params.required(:tags, :array, of: :string)
      schema = params.to_json_schema

      expect(schema[:properties]["tags"][:items]).must_equal({ type: "string" })
    end

    it "supports block on Hash for nested objects" do
      params = Riffer::Params.new
      params.required(:address, :object) do
        required :street, :string
        required :city, :string
        optional :zip, :string
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
      params.required(:line_items, :array) do
        required :product, :string
        required :quantity, :integer
        optional :note, :string
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
        params.required(:tags, :array, of: :string) do
          required :name, :string
        end
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is Hash" do
      params = Riffer::Params.new

      expect do
        params.required(:items, :array, of: :object)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is Array" do
      params = Riffer::Params.new

      expect do
        params.required(:items, :array, of: :array)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is a non-JSON-Schema type" do
      params = Riffer::Params.new

      expect do
        params.required(:items, :array, of: Regexp)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is used on Hash type" do
      params = Riffer::Params.new

      expect do
        params.required(:data, :object, of: :string)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when of: is used on String type" do
      params = Riffer::Params.new

      expect do
        params.required(:name, :string, of: :string)
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when block is used on String type" do
      params = Riffer::Params.new

      expect do
        params.required(:name, :string) { required :foo, :string }
      end.must_raise(Riffer::ArgumentError)
    end

    it "raises ArgumentError when block is used on Integer type" do
      params = Riffer::Params.new

      expect do
        params.optional(:count, :integer) { required :foo, :string }
      end.must_raise(Riffer::ArgumentError)
    end

    it "supports deep nesting with blocks within blocks" do
      params = Riffer::Params.new
      params.required(:orders, :array) do
        required :shipping, :object do
          required :address, :object do
            required :street, :string
          end
        end
      end
      schema = params.to_json_schema
      street = schema.dig(
        :properties,
        "orders",
        :items,
        :properties,
        "shipping",
        :properties,
        "address",
        :properties,
        "street",
      )

      expect(street).must_equal({ type: "string" })
    end
  end

  describe "#validate with nested params" do
    it "validates typed array accepts valid items" do
      params = Riffer::Params.new
      params.required(:tags, :array, of: :string)
      result = params.validate({ tags: %w[a b] })

      expect(result[:tags]).must_equal %w[a b]
    end

    it "validates typed array rejects invalid items" do
      params = Riffer::Params.new
      params.required(:tags, :array, of: :string)
      error = expect { params.validate({ tags: ["a", 123] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/tags\[1\] must be a string/)
    end

    it "validates nested Hash recursively with dot-path errors" do
      params = Riffer::Params.new
      params.required(:address, :object) do
        required :street, :string
        required :city, :string
      end
      error = expect do
        params.validate({ address: { street: "123 Main" } })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/address\.city is required/)
    end

    it "validates array of objects with indexed errors" do
      params = Riffer::Params.new
      params.required(:items, :array) do
        required :name, :string
        required :qty, :integer
      end
      error = expect do
        params.validate({ items: [{ name: "A", qty: 1 }, { name: "B" }] })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/items\[1\]\.qty is required/)
    end

    it "validates deep nesting with correct dot-path errors" do
      params = Riffer::Params.new
      params.required(:orders, :array) do
        required :shipping, :object do
          required :address, :object do
            required :street, :string
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
      params.required(:address, :object) do
        required :city, :string
      end
      result = params.validate({ address: { city: "Toronto" } })

      expect(result[:address]).must_equal({ city: "Toronto" })
    end

    it "accepts valid array of objects" do
      params = Riffer::Params.new
      params.required(:items, :array) do
        required :name, :string
      end
      result = params.validate({ items: [{ name: "A" }, { name: "B" }] })

      expect(result[:items]).must_equal [{ name: "A" }, { name: "B" }]
    end

    it "accepts a float for a Float param" do
      params = Riffer::Params.new
      params.required(:price, :number)

      expect(params.validate({ price: 120.5 })[:price]).must_equal 120.5
    end

    it "accepts an integer for a Float param and coerces it to a float" do
      params = Riffer::Params.new
      params.required(:price, :number)
      result = params.validate({ price: 120 })

      expect(result[:price]).must_equal 120.0
      expect(result[:price]).must_be_instance_of Float
    end

    it "rejects a string for a Float param" do
      params = Riffer::Params.new
      params.required(:price, :number)
      error = expect { params.validate({ price: "120" }) }.must_raise(Riffer::ValidationError)

      expect(error.message).must_match(/price must be a number/)
    end

    it "rejects a boolean for a Float param" do
      params = Riffer::Params.new
      params.required(:price, :number)
      error = expect { params.validate({ price: true }) }.must_raise(Riffer::ValidationError)

      expect(error.message).must_match(/price must be a number/)
    end

    it "rejects a float for an Integer param" do
      params = Riffer::Params.new
      params.required(:quantity, :integer)
      error = expect { params.validate({ quantity: 1.5 }) }.must_raise(Riffer::ValidationError)

      expect(error.message).must_match(/quantity must be an? integer/)
    end

    it "accepts an integer for a Float param nested in an array of objects" do
      params = Riffer::Params.new
      params.required(:treatments, :array) do
        required :price, :number
      end
      result = params.validate({ treatments: [{ price: 120 }] })

      expect(result[:treatments]).must_equal [{ price: 120.0 }]
      expect(result[:treatments].first[:price]).must_be_instance_of Float
    end

    it "accepts an integer for a Float param nested in a Hash" do
      params = Riffer::Params.new
      params.required(:invoice, :object) do
        required :total, :number
      end
      result = params.validate({ invoice: { total: 120 } })

      expect(result[:invoice][:total]).must_be_instance_of Float
    end

    it "accepts mixed numerics in an of: :number array and coerces them to floats" do
      params = Riffer::Params.new
      params.required(:scores, :array, of: :number)
      result = params.validate({ scores: [1, 2.5] })

      expect(result[:scores]).must_equal [1.0, 2.5]
      expect(result[:scores].map(&:class)).must_equal [Float, Float]
    end

    it "rejects a non-numeric item in an of: :number array" do
      params = Riffer::Params.new
      params.required(:scores, :array, of: :number)
      error = expect { params.validate({ scores: [1, "2"] }) }.must_raise(Riffer::ValidationError)

      expect(error.message).must_match(/scores\[1\] must be a number/)
    end

    it "rejects a float item in an of: :integer array" do
      params = Riffer::Params.new
      params.required(:counts, :array, of: :integer)
      error = expect { params.validate({ counts: [1, 2.5] }) }.must_raise(Riffer::ValidationError)

      expect(error.message).must_match(/counts\[1\] must be an? integer/)
    end
  end

  describe "#to_json_schema" do
    it "returns object type" do
      params = Riffer::Params.new

      expect(params.to_json_schema[:type]).must_equal "object"
    end

    it "includes properties for each parameter" do
      params = Riffer::Params.new
      params.required(:city, :string)
      params.optional(:units, :string)
      schema = params.to_json_schema

      expect(schema[:properties].keys).must_equal %w[city units]
    end

    it "includes required array" do
      params = Riffer::Params.new
      params.required(:city, :string)
      params.optional(:units, :string)
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
      params.required(:name, :string)
      params.optional(:age, :integer)
      schema = params.to_json_schema(strict: true)

      expect(schema[:required]).must_include "name"
      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["name"][:type]).must_equal "string"
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
    end

    it "recurses into nested objects" do
      params = Riffer::Params.new
      params.required(:address, :object) do
        required :city, :string
        optional :zip, :string
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
      params.required(:items, :array) do
        required :name, :string
        optional :note, :string
      end
      schema = params.to_json_schema(strict: true)
      items_schema = schema[:properties]["items"][:items]

      expect(items_schema[:required]).must_include "name"
      expect(items_schema[:required]).must_include "note"
      expect(items_schema[:properties]["name"][:type]).must_equal "string"
      expect(items_schema[:properties]["note"][:type]).must_equal %w[string null]
    end

    it "makes an optional object with nested params nullable" do
      params = Riffer::Params.new
      params.optional(:definition, :object) do
        required :name, :string
      end
      schema = params.to_json_schema(strict: true)
      definition = schema[:properties]["definition"]

      expect(definition[:type]).must_equal %w[object null]
      expect(definition[:properties]["name"][:type]).must_equal "string"
      expect(definition[:required]).must_equal ["name"]
    end

    it "makes an optional array with nested params nullable" do
      params = Riffer::Params.new
      params.optional(:items, :array) do
        required :name, :string
      end
      schema = params.to_json_schema(strict: true)
      items = schema[:properties]["items"]

      expect(items[:type]).must_equal %w[array null]
      expect(items[:items][:type]).must_equal "object"
      expect(items[:items][:properties]["name"][:type]).must_equal "string"
    end

    it "makes an optional typed array nullable" do
      params = Riffer::Params.new
      params.optional(:tags, :array, of: :string)
      schema = params.to_json_schema(strict: true)
      tags = schema[:properties]["tags"]

      expect(tags[:type]).must_equal %w[array null]
      expect(tags[:items]).must_equal({ type: "string" })
    end

    it "keeps required properties non-nullable" do
      params = Riffer::Params.new
      params.required(:name, :string)
      schema = params.to_json_schema(strict: true)

      expect(schema[:properties]["name"][:type]).must_equal "string"
    end

    it "emits default in non-strict mode" do
      params = Riffer::Params.new
      params.optional(:units, :string, default: "celsius")
      schema = params.to_json_schema(strict: false)

      expect(schema[:properties]["units"][:default]).must_equal "celsius"
    end

    it "omits default in strict mode" do
      params = Riffer::Params.new
      params.optional(:units, :string, default: "celsius")
      schema = params.to_json_schema(strict: true)

      expect(schema[:properties]["units"].key?(:default)).must_equal false
    end

    it "omits default when none is set" do
      params = Riffer::Params.new
      params.optional(:units, :string)
      schema = params.to_json_schema(strict: false)

      expect(schema[:properties]["units"].key?(:default)).must_equal false
    end

    it "raises ArgumentError for a Hash param without a block" do
      params = Riffer::Params.new
      params.required(:applies_when, :object)

      error = expect { params.to_json_schema(strict: true) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal(
        "applies_when: an :object param requires a block defining its properties under strict schemas",
      )
    end

    it "renders a Hash param without a block in non-strict mode" do
      params = Riffer::Params.new
      params.required(:applies_when, :object, description: "Conditions")

      expect(params.to_json_schema[:properties]["applies_when"]).must_equal(
        type: "object", description: "Conditions",
      )
    end

    it "renders a Hash param with a block as a closed object" do
      params = Riffer::Params.new
      params.required(:address, :object) do
        required :city, :string
      end
      address = params.to_json_schema(strict: true)[:properties]["address"]

      expect(address).must_equal(
        type: "object",
        properties: { "city" => { type: "string" } },
        required: ["city"],
        additionalProperties: false,
      )
    end

    it "raises ArgumentError for an Array param without a block or of:" do
      params = Riffer::Params.new
      params.required(:tags, :array)

      error = expect { params.to_json_schema(strict: true) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal(
        "tags: an :array param requires a block or of: defining its items under strict schemas",
      )
    end

    it "renders an Array param without a block or of: in non-strict mode" do
      params = Riffer::Params.new
      params.required(:tags, :array)

      expect(params.to_json_schema[:properties]["tags"]).must_equal(type: "array")
    end

    it "raises ArgumentError for a Hash param without a block nested inside a block" do
      params = Riffer::Params.new
      params.required(:shipping, :object) do
        required :address, :object
      end

      error = expect { params.to_json_schema(strict: true) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_include "address: an :object param requires a block"
    end
  end

  describe ".from_json_schema" do
    it "reconstructs a simple required parameter" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: { "city" => { type: "string", description: "city name" } },
          required: ["city"],
          additionalProperties: false,
        },
      )
      param = params.parameters.first

      expect(param.name).must_equal :city
      expect(param.type).must_equal :string
      expect(param.required).must_equal true
      expect(param.description).must_equal "city name"
    end

    it "marks properties absent from required as optional" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: { "note" => { type: "string" } },
          required: [],
          additionalProperties: false,
        },
      )

      expect(params.parameters.first.required).must_equal false
    end

    it "reconstructs enum and default" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: { "units" => { type: "string", enum: %w[celsius fahrenheit], default: "celsius" } },
          required: [],
          additionalProperties: false,
        },
      )
      param = params.parameters.first

      expect(param.enum).must_equal %w[celsius fahrenheit]
      expect(param.default).must_equal "celsius"
    end

    it "reconstructs each JSON Schema type to its type symbol" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: {
            "s" => { type: "string" }, "i" => { type: "integer" },
            "n" => { type: "number" }, "b" => { type: "boolean" },
          },
          required: [],
          additionalProperties: false,
        },
      )
      types = params.parameters.to_h { |p| [p.name, p.type] }

      expect(types).must_equal({ s: :string, i: :integer, n: :number, b: :boolean })
    end

    it "reconstructs typed arrays" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: { "tags" => { type: "array", items: { type: "integer" } } },
          required: ["tags"],
          additionalProperties: false,
        },
      )

      expect(params.parameters.first.item_type).must_equal :integer
    end

    it "reconstructs nested object params" do
      params = Riffer::Params.from_json_schema(
        {
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
        },
      )
      nested = params.parameters.first.nested_params

      expect(nested).must_be_instance_of Riffer::Params
      expect(nested.parameters.first.name).must_equal :street
    end

    it "raises on an unsupported JSON Schema type" do
      expect do
        Riffer::Params.from_json_schema(
          {
            type: "object",
            properties: { "x" => { type: "anyOf-thing" } },
            required: [],
            additionalProperties: false,
          },
        )
      end.must_raise Riffer::ArgumentError
    end

    it "round-trips losslessly with to_json_schema(strict: false)" do
      params = Riffer::Params.new
      params.required(:city, :string, description: "city name")
      params.optional(:units, :string, default: "celsius", enum: %w[celsius fahrenheit])
      params.required(:tags, :array, of: :integer)
      params.required(:address, :object) do
        required :street, :string
        optional :zip, :string
      end
      params.required(:contacts, :array) do
        required :name, :string
      end
      schema = params.to_json_schema(strict: false)

      rebuilt = Riffer::Params.from_json_schema(schema)

      expect(rebuilt.to_json_schema(strict: false)).must_equal schema
    end

    it "round-trips through JSON with symbolized keys" do
      params = Riffer::Params.new
      params.optional(:units, :string, default: "celsius")
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

    it "reconstructs anyOf as an AnyOf param with one variant per branch" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: {
            "result" => {
              anyOf: [
                { type: "object", properties: { "name" => { type: "string" } }, required: ["name"] },
                { type: "object", properties: { "error_code" => { type: "string" } }, required: ["error_code"] },
              ],
            },
          },
          required: ["result"],
          additionalProperties: false,
        },
      )
      param = params.parameters.first

      expect(param.type).must_equal :any_of
      expect(param.variants.map { |variant| variant.parameters.map(&:name) }).must_equal [%i[name], %i[error_code]]
    end

    it "ignores the null branch strict schemas add to an optional anyOf" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: {
            "result" => {
              anyOf: [
                { type: "object", properties: { "name" => { type: "string" } }, required: ["name"] },
                { type: "object", properties: { "error_code" => { type: "string" } }, required: ["error_code"] },
                { type: "null" },
              ],
            },
          },
          required: [],
          additionalProperties: false,
        },
      )

      expect(params.parameters.first.variants.length).must_equal 2
    end

    it "reconstructs primitive anyOf branches as primitive variants" do
      params = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: {
            "due" => {
              anyOf: [
                { type: "string", format: "date", description: "The due date" },
                { type: "string", enum: ["none"] },
                { type: "integer" },
              ],
            },
          },
          required: ["due"],
        },
      )
      variants = params.parameters.first.variants

      expect(variants.map { |variant| [variant.type, variant.format, variant.enum, variant.description] }).must_equal [
        [:string, "date", nil, "The due date"], [:string, nil, ["none"], nil], [:integer, nil, nil, nil],
      ]
      expect(variants.map(&:required)).must_equal [true, true, true]
    end

    it "raises on an anyOf branch that is not a plain object or primitive" do
      [
        { type: "array", items: { type: "string" } },
        { type: %w[string null] },
        { type: "string", anyOf: [{ type: "string" }, { type: "integer" }] },
      ].each do |branch|
        error = expect do
          Riffer::Params.from_json_schema(
            {
              type: "object",
              properties: { "result" => { anyOf: [{ type: "string" }, branch] } },
              required: ["result"],
            },
          )
        end.must_raise Riffer::ArgumentError
        expect(error.message).must_equal "Unsupported anyOf branch: #{branch.to_json}"
      end
    end

    it "raises on the nullable enum shape strict schemas emit" do
      error = expect do
        Riffer::Params.from_json_schema(
          {
            type: "object",
            properties: { "unit" => { anyOf: [{ type: "string", enum: %w[c f] }, { type: "null" }] } },
            required: ["unit"],
            additionalProperties: false,
          },
        )
      end.must_raise Riffer::ArgumentError
      expect(error.message).must_equal "anyOf requires at least two branches"
    end

    it "raises on a union of types instead of narrowing it to the first" do
      error = expect do
        Riffer::Params.from_json_schema(
          { type: "object", properties: { "quantity" => { type: %w[integer string] } }, required: ["quantity"] },
        )
      end.must_raise Riffer::ArgumentError
      expect(error.message).must_equal 'Unsupported JSON Schema type: ["integer", "string"]'
    end

    it "raises on an anyOf with fewer than two branches" do
      error = expect do
        Riffer::Params.from_json_schema(
          {
            type: "object",
            properties: {
              "result" => {
                anyOf: [
                  { type: "object", properties: { "name" => { type: "string" } }, required: ["name"] },
                  { type: "null" },
                ],
              },
            },
            required: [],
            additionalProperties: false,
          },
        )
      end.must_raise Riffer::ArgumentError
      expect(error.message).must_equal "anyOf requires at least two branches"
    end

    it "round-trips an AnyOf param losslessly with to_json_schema(strict: false)" do
      params = Riffer::Params.new
      params.optional(
        :result, :any_of, description: "A rule or an error", default: { name: "Fallback" },
      ) do
        variant do
          required :name, :string
          optional :tags, :array, of: :string
        end
        variant do
          required :error_code, :string, enum: %w[non_english unsupported]
          required :details, :object do
            required :message, :string
          end
        end
      end
      schema = params.to_json_schema(strict: false)
      wire = JSON.parse(JSON.generate(schema), symbolize_names: true)

      rebuilt = Riffer::Params.from_json_schema(wire)

      expect(rebuilt.to_json_schema(strict: false)).must_equal schema
      expect(rebuilt.to_json_schema(strict: true)).must_equal params.to_json_schema(strict: true)
      expect(rebuilt.parameters.first.default).must_equal({ name: "Fallback" })
    end

    it "round-trips an AnyOf param with primitive and object variants" do
      params = Riffer::Params.new
      params.optional(:due, :any_of, description: "When it's due") do
        variant :string, format: "date", description: "The due date"
        variant :string, enum: ["none"]
        variant :integer
        variant { required :days, :integer }
      end
      schema = params.to_json_schema(strict: false)
      wire = JSON.parse(JSON.generate(schema), symbolize_names: true)

      rebuilt = Riffer::Params.from_json_schema(wire)

      expect(rebuilt.to_json_schema(strict: false)).must_equal schema
      expect(rebuilt.to_json_schema(strict: true)).must_equal params.to_json_schema(strict: true)
    end
  end
  describe "#dup" do
    it "holds no collection in common with the original, at any depth" do
      original = Riffer::Params.new
      original.required(:claim, :object) { required :id, :string }

      copy = original.dup
      copy.required(:verdict, :string)
      copy.parameters.first.nested_params.required(:amount, :number)

      expect(original.parameters.map(&:name)).must_equal %i[claim]
      expect(original.parameters.first.nested_params.parameters.map(&:name)).must_equal %i[id]
      expect(copy.parameters.map(&:name)).must_equal %i[claim verdict]
    end

    it "does not share a mutable enum or default with the original" do
      original = Riffer::Params.new
      original.optional(:status, :string, enum: %w[open closed], default: { note: ["seen"] })

      copy = original.dup
      copy.parameters.first.enum << "archived"
      copy.parameters.first.default[:note] << "edited"

      expect(original.parameters.first.enum).must_equal %w[open closed]
      expect(original.parameters.first.default).must_equal({ note: ["seen"] })
    end

    it "produces an equivalent schema" do
      original = Riffer::Params.new
      original.required(:answer, :string, description: "the answer")
      original.optional(:score, :number, default: 0.0)

      expect(original.dup.to_json_schema(strict: false)).
        must_equal original.to_json_schema(strict: false)
    end
  end

  describe "AnyOf" do
    let(:params) do
      params = Riffer::Params.new
      params.required(:result, :any_of, description: "A rule or an error") do
        variant do
          required :name, :string
          optional :note, :string
        end
        variant do
          required :error_code, :string, enum: %w[non_english unsupported]
        end
      end
      params
    end

    it "builds one Params per variant" do
      variants = params.parameters.first.variants

      expect(variants.map { |variant| variant.parameters.map(&:name) }).must_equal [%i[name note], %i[error_code]]
    end

    it "raises ArgumentError without a block" do
      error = expect do
        Riffer::Params.new.required(:result, :any_of)
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal ":any_of requires a block defining its variants"
    end

    it "raises ArgumentError with fewer than two variants" do
      error = expect do
        Riffer::Params.new.required(:result, :any_of) do
          variant { required :name, :string }
        end
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal ":any_of requires at least two variants"
    end

    it "raises ArgumentError for a variant without a type or a block" do
      error = expect do
        Riffer::Params.new.required(:result, :any_of) { variant }
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "variant requires a type or a block defining its properties"
    end

    it "raises ArgumentError with of:" do
      error = expect do
        Riffer::Params.new.required(:result, :any_of, of: :string)
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "of: cannot be used with :any_of"
    end

    it "raises ArgumentError with enum:" do
      error = expect do
        Riffer::Params.new.optional(:result, :any_of, enum: %w[a b])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "enum: cannot be used with :any_of"
    end

    it "renders one object schema per variant" do
      expect(params.to_json_schema[:properties]["result"]).must_equal(
        anyOf: [
          {
            type: "object",
            properties: { "name" => { type: "string" }, "note" => { type: "string" } },
            required: ["name"],
            additionalProperties: false,
          },
          {
            type: "object",
            properties: { "error_code" => { type: "string", enum: %w[non_english unsupported] } },
            required: ["error_code"],
            additionalProperties: false,
          },
        ],
        description: "A rule or an error",
      )
    end

    it "renders each variant as a strict schema in strict mode" do
      result = params.to_json_schema(strict: true)[:properties]["result"]

      expect(result[:anyOf].length).must_equal 2
      expect(result[:anyOf].first[:required]).must_equal %w[name note]
      expect(result[:anyOf].first[:properties]["note"][:type]).must_equal %w[string null]
    end

    it "adds a null branch when optional in strict mode" do
      params = Riffer::Params.new
      params.optional(:result, :any_of) do
        variant { required :name, :string }
        variant { required :error_code, :string }
      end
      result = params.to_json_schema(strict: true)[:properties]["result"]

      expect(result[:anyOf].length).must_equal 3
      expect(result[:anyOf].last).must_equal(type: "null")
    end

    it "adds no null branch when optional in non-strict mode" do
      params = Riffer::Params.new
      params.optional(:result, :any_of) do
        variant { required :name, :string }
        variant { required :error_code, :string }
      end

      expect(params.to_json_schema[:properties]["result"][:anyOf].length).must_equal 2
    end

    it "raises ArgumentError for a bare Hash inside a variant under strict schemas" do
      params = Riffer::Params.new
      params.required(:result, :any_of) do
        variant { required :definition, :object }
        variant { required :error_code, :string }
      end

      error = expect { params.to_json_schema(strict: true) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_include "definition: an :object param requires a block"
    end

    it "accepts a value matching the first variant" do
      result = params.validate({ result: { name: "Rule", note: "Checked" } })

      expect(result[:result]).must_equal({ name: "Rule", note: "Checked" })
    end

    it "accepts a value matching the second variant" do
      result = params.validate({ result: { error_code: "non_english" } })

      expect(result[:result]).must_equal({ error_code: "non_english" })
    end

    it "returns the matched variant's coerced values and defaults" do
      params = Riffer::Params.new
      params.required(:result, :any_of) do
        variant do
          required :score, :number
          optional :weight, :number, default: 1.5
        end
        variant { required :error_code, :string }
      end

      expect(params.validate({ result: { score: 2 } })).must_equal({ result: { score: 2.0, weight: 1.5 } })
    end

    it "rejects keys the matched variant does not define" do
      error = expect do
        params.validate({ result: { name: "Rule", error_code: "non_english" } })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "result must match one of the variants: " \
        "variant 1 (error_code is not allowed), variant 2 (name is not allowed)",
      )
    end

    it "rejects keys no variant defines" do
      error = expect { params.validate({ result: { name: "Rule", extra: 1 } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "result must match one of the variants: " \
        "variant 1 (extra is not allowed), variant 2 (error_code is required)",
      )
    end

    it "validates an AnyOf inside an array of objects with dot-path errors" do
      params = Riffer::Params.new
      params.required(:items, :array) do
        required :result, :any_of do
          variant { required :name, :string }
          variant { required :error_code, :string }
        end
      end

      error = expect { params.validate({ items: [{ result: {} }] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "items[0].result must match one of the variants: " \
        "variant 1 (name is required), variant 2 (error_code is required)",
      )
    end

    it "does not let an earlier variant swallow a later one's keys" do
      params = Riffer::Params.new
      params.required(:result, :any_of) do
        variant { optional :note, :string }
        variant { required :error_code, :string }
      end

      expect(params.validate({ result: { error_code: "unsupported" } })).
        must_equal({ result: { error_code: "unsupported" } })
    end

    it "does not let an earlier variant swallow a later one's nested keys" do
      params = Riffer::Params.new
      params.required(:result, :any_of) do
        variant { required(:payload, :object) { required :kind, :string } }
        variant do
          required(:payload, :object) do
            required :kind, :string
            required :detail, :string
          end
        end
      end

      expect(params.validate({ result: { payload: { kind: "x", detail: "d" } } })).
        must_equal({ result: { payload: { kind: "x", detail: "d" } } })
    end

    it "rejects undeclared keys inside arrays of objects with their path" do
      params = Riffer::Params.new
      params.required(:result, :any_of) do
        variant { required(:rows, :array) { required :id, :integer } }
        variant { required :error_code, :string }
      end

      error = expect do
        params.validate({ result: { rows: [{ id: 1 }, { id: 2, extra: 3 }] } })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "result must match one of the variants: " \
        "variant 1 (rows[1].extra is not allowed), variant 2 (error_code is required)",
      )
    end

    it "rejects a value where every field is null" do
      error = expect do
        params.validate({ result: { name: nil, note: nil, error_code: nil } })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "result must match one of the variants: variant 1 (name is required), variant 2 (error_code is required)",
      )
    end

    it "reports every error of each variant" do
      error = expect do
        params.validate({ result: { note: 1, error_code: "spanish" } })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "result must match one of the variants: " \
        "variant 1 (name is required, note must be a string), " \
        "variant 2 (error_code must be one of: non_english, unsupported)",
      )
    end

    it "rejects a value that is not an object" do
      error = expect { params.validate({ result: "Rule" }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "result must be a object"
    end

    it "requires a value when required" do
      error = expect { params.validate({}) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "result is required"
    end

    it "accepts a missing value when optional" do
      params = Riffer::Params.new
      params.optional(:result, :any_of) do
        variant { required :name, :string }
        variant { required :error_code, :string }
      end

      expect(params.validate({})).must_equal({ result: nil })
    end

    it "prefixes errors with the path of an enclosing object" do
      outer = Riffer::Params.new
      outer.required(:review, :object) do
        required :result, :any_of do
          variant { required :name, :string }
          variant { required :error_code, :string }
        end
      end

      error = expect { outer.validate({ review: { result: {} } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "review.result must match one of the variants: " \
        "variant 1 (name is required), variant 2 (error_code is required)",
      )
    end

    it "does not share variants with a copy" do
      copy = params.dup
      copy.parameters.first.variants.first.required(:extra, :string)

      expect(params.parameters.first.variants.first.parameters.map(&:name)).must_equal %i[name note]
    end
  end

  describe "AnyOf with primitive variants" do
    let(:params) do
      params = Riffer::Params.new
      params.required(:quantity, :any_of, description: "A count or a word") do
        variant :integer
        variant :string
      end
      params.optional(:due, :any_of) do
        variant :string, format: "date", description: "The due date"
        variant :string, enum: ["none"]
      end
      params
    end

    it "raises ArgumentError for a variant with both a type and a block" do
      error = expect do
        Riffer::Params.new.required(:result, :any_of) do
          variant(:string) { required :name, :string }
          variant :integer
        end
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "variant takes a type or a block, not both"
    end

    it "raises ArgumentError for a variant type that is not primitive" do
      error = expect do
        Riffer::Params.new.required(:result, :any_of) do
          variant :object
          variant :string
        end
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal(
        "variant type must be one of :string, :integer, :number, :boolean, got :object",
      )
    end

    it "raises ArgumentError for an Integer variant after a Float variant" do
      error = expect do
        Riffer::Params.new.required(:amount, :any_of) do
          variant :number
          variant :integer
        end
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal(
        "amount: an :integer variant after a :number variant without enum: can never match",
      )
    end

    it "allows an Integer variant after a Float variant with an enum" do
      params = Riffer::Params.new
      params.required(:amount, :any_of) do
        variant :number, enum: [1.5]
        variant :integer
      end

      expect(params.validate({ amount: 3 })).must_equal({ amount: 3 })
    end

    it "raises ArgumentError for a block variant with description:, enum: or format:" do
      [{ description: "An email" }, { enum: ["x"] }, { format: "email" }].each do |options|
        error = expect do
          Riffer::Params.new.required(:contact, :any_of) do
            variant(**options) { required :email, :string }
            variant :string
          end
        end.must_raise(Riffer::ArgumentError)
        expect(error.message).must_equal "description:, enum: and format: only apply to a primitive variant"
      end
    end

    it "raises ArgumentError for a variant with both enum: and format:" do
      error = expect do
        Riffer::Params.new.required(:due, :any_of) do
          variant :string, format: "date", enum: ["2026-01-01"]
          variant :integer
        end
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "due: format: cannot be used with enum:"
    end

    it "renders one branch per variant" do
      expect(params.to_json_schema[:properties]).must_equal(
        "quantity" => { anyOf: [{ type: "integer" }, { type: "string" }], description: "A count or a word" },
        "due" => {
          anyOf: [{ type: "string", description: "The due date", format: "date" }, { type: "string", enum: ["none"] }],
        },
      )
    end

    it "adds a single null branch to an optional field in strict mode" do
      expect(params.to_json_schema(strict: true)[:properties]["due"]).must_equal(
        anyOf: [
          { type: "string", description: "The due date", format: "date" },
          { type: "string", enum: ["none"] },
          { type: "null" },
        ],
      )
    end

    it "accepts a value matching any variant" do
      expect(params.validate({ quantity: 3, due: "2026-11-03" })).must_equal({ quantity: 3, due: "2026-11-03" })
      expect(params.validate({ quantity: "several", due: "none" })).must_equal({ quantity: "several", due: "none" })
    end

    it "accepts a missing value when optional" do
      expect(params.validate({ quantity: 3 })).must_equal({ quantity: 3, due: nil })
    end

    it "rejects a value whose type matches no variant" do
      error = expect { params.validate({ quantity: true }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "quantity must be a integer or string"
    end

    it "reports each variant's error when the type matches but no variant passes" do
      error = expect { params.validate({ quantity: 1, due: "soon" }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "due must match one of the variants: variant 1 (must be a valid date), variant 2 (must be one of: none)",
      )
    end

    it "keeps integers from an Integer variant and coerces a Float variant's values" do
      params = Riffer::Params.new
      params.required(:amount, :any_of) do
        variant :integer
        variant :number
      end
      params.required(:ratio, :any_of) do
        variant :string
        variant :number
      end

      expect(params.validate({ amount: 3, ratio: 1 })).must_equal({ amount: 3, ratio: 1.0 })
      expect(params.validate({ amount: 2.5, ratio: "half" })).must_equal({ amount: 2.5, ratio: "half" })
    end

    it "accepts a primitive or an object when a field has both kinds of variant" do
      params = Riffer::Params.new
      params.required(:contact, :any_of) do
        variant :string
        variant { required :email, :string }
      end

      expect(params.validate({ contact: "front desk" })).must_equal({ contact: "front desk" })
      expect(params.validate({ contact: { email: "a@b.co" } })).must_equal({ contact: { email: "a@b.co" } })

      error = expect { params.validate({ contact: { phone: "555" } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "contact must match one of the variants: variant 1 (must be a string), variant 2 (email is required)",
      )
    end

    it "prefixes errors with the path of an enclosing object" do
      outer = Riffer::Params.new
      outer.required(:item, :object) do
        required :quantity, :any_of do
          variant :integer
          variant :string
        end
      end

      error = expect { outer.validate({ item: { quantity: [1] } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "item.quantity must be a integer or string"
    end
  end

  describe "Array of enum values" do
    let(:params) do
      params = Riffer::Params.new
      params.required(:tags, :array, of: :string, enum: %w[urgent billing follow_up])
      params
    end

    it "raises ArgumentError with enum: on an Array without of:" do
      error = expect do
        Riffer::Params.new.required(:tags, :array, enum: [%w[urgent]])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "enum: with :array requires of:"
    end

    it "raises ArgumentError with enum: on an Array with a block" do
      error = expect do
        Riffer::Params.new.required(:items, :array, enum: %w[urgent]) { required :name, :string }
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "enum: with :array requires of:"
    end

    it "raises ArgumentError with enum: on a Hash" do
      error = expect do
        Riffer::Params.new.optional(:address, :object, enum: [{ city: "Toronto" }]) { required :city, :string }
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "enum: cannot be used with :object"
    end

    it "renders the enum on the items" do
      expect(params.to_json_schema[:properties]["tags"]).must_equal(
        type: "array", items: { type: "string", enum: %w[urgent billing follow_up] },
      )
    end

    it "keeps the items when optional in strict mode" do
      params = Riffer::Params.new
      params.optional(:days, :array, of: :integer, enum: [1, 2, 3])

      expect(params.to_json_schema(strict: true)[:properties]["days"]).must_equal(
        type: %w[array null], items: { type: "integer", enum: [1, 2, 3] },
      )
    end

    it "accepts items from the enum" do
      expect(params.validate({ tags: %w[urgent follow_up] })).must_equal({ tags: %w[urgent follow_up] })
    end

    it "accepts an empty array" do
      expect(params.validate({ tags: [] })).must_equal({ tags: [] })
    end

    it "rejects an item outside the enum with its index" do
      error = expect { params.validate({ tags: %w[urgent spam] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "tags[1] must be one of: urgent, billing, follow_up"
    end

    it "rejects an item of the wrong type before checking the enum" do
      error = expect { params.validate({ tags: ["urgent", 1] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "tags[1] must be a string"
    end

    it "coerces integer items of an of: :number enum to floats" do
      params = Riffer::Params.new
      params.required(:weights, :array, of: :number, enum: [0.5, 1.0])

      expect(params.validate({ weights: [1, 0.5] })).must_equal({ weights: [1.0, 0.5] })
    end

    it "prefixes errors with the path of an enclosing object" do
      outer = Riffer::Params.new
      outer.required(:ticket, :object) { required :tags, :array, of: :string, enum: %w[urgent billing] }

      error = expect { outer.validate({ ticket: { tags: %w[spam] } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "ticket.tags[0] must be one of: urgent, billing"
    end

    it "accepts items from the enum inside an AnyOf variant" do
      outer = Riffer::Params.new
      outer.required(:result, :any_of) do
        variant { required :tags, :array, of: :string, enum: %w[urgent billing] }
        variant { required :error_code, :string }
      end

      expect(outer.validate({ result: { tags: %w[billing] } })).must_equal({ result: { tags: %w[billing] } })
    end

    it "reads the enum back from the items" do
      rebuilt = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: { "tags" => { type: "array", items: { type: "string", enum: %w[urgent billing] } } },
          required: ["tags"],
          additionalProperties: false,
        },
      )

      expect(rebuilt.parameters.first.enum).must_equal %w[urgent billing]
      expect { rebuilt.validate({ tags: %w[spam] }) }.must_raise(Riffer::ValidationError)
    end

    it "round-trips losslessly with to_json_schema(strict: false)" do
      schema = params.to_json_schema(strict: false)

      expect(Riffer::Params.from_json_schema(schema).to_json_schema(strict: false)).must_equal schema
    end

    it "reads an enum written on the array and renders it on the items" do
      rebuilt = Riffer::Params.from_json_schema(
        {
          type: "object",
          properties: { "tags" => { type: "array", enum: %w[urgent billing], items: { type: "string" } } },
          required: ["tags"],
          additionalProperties: false,
        },
      )

      expect(rebuilt.to_json_schema[:properties]["tags"]).must_equal(
        type: "array", items: { type: "string", enum: %w[urgent billing] },
      )
    end
  end

  describe "format" do
    let(:params) do
      params = Riffer::Params.new
      params.required(:born_on, :string, format: "date")
      params.optional(:email, :string, format: "email")
      params.required(:visit_ids, :array, of: :string, format: "uuid")
      params
    end

    let(:visit_id) { "550e8400-e29b-41d4-a716-446655440000" }

    it "raises ArgumentError with a format outside the supported list" do
      error = expect { Riffer::Params.new.required(:site, :string, format: "uri") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal(
        "site: format: must be a supported format " \
        '(date-time, time, date, duration, email, hostname, ipv4, ipv6, uuid), got "uri"',
      )
    end

    it "raises ArgumentError with a format that isn't a string" do
      error = expect { Riffer::Params.new.required(:on, :string, format: :date) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/\Aon: format: must be a supported format \(.*\), got :date\z/)
    end

    it "raises ArgumentError with format: on a non-String type" do
      error = expect { Riffer::Params.new.required(:age, :integer, format: "date") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "age: format: requires :string or an :array whose innermost type is :string"
    end

    it "raises ArgumentError with format: on an Array of a non-String type" do
      error = expect do
        Riffer::Params.new.required(:ages, :array, of: :integer, format: "date")
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "ages: format: requires :string or an :array whose innermost type is :string"
    end

    it "raises ArgumentError with format: on a Hash, an Array of objects or an AnyOf" do
      [
        -> { required(:address, :object, format: "date") { required :city, :string } },
        -> { required(:visits, :array, format: "date") { required :on, :string } },
        lambda do
          required :result, :any_of, format: "date" do
            variant { required :on, :string }
            variant { required :error, :string }
          end
        end,
      ].each do |definition|
        error = expect { Riffer::Params.new.instance_exec(&definition) }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/format: requires :string or an :array whose innermost type is :string\z/)
      end
    end

    it "raises ArgumentError with format: and enum:" do
      error = expect do
        Riffer::Params.new.required(:born_on, :string, format: "date", enum: ["2026-10-19"])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "born_on: format: cannot be used with enum:"
    end

    it "keeps its own frozen copy of the format" do
      format = +"date"
      param = Riffer::Params::Param.new(name: :on, type: :string, required: true, format: format)
      format << "-time"

      expect(param.format).must_equal "date"
      expect(param.format).must_be :frozen?
    end

    it "renders the format on the field and on typed array items" do
      expect(params.to_json_schema[:properties]).must_equal(
        "born_on" => { type: "string", format: "date" },
        "email" => { type: "string", format: "email" },
        "visit_ids" => { type: "array", items: { type: "string", format: "uuid" } },
      )
    end

    it "keeps the format next to the nullable type when optional in strict mode" do
      expect(params.to_json_schema(strict: true)[:properties]["email"]).must_equal(
        type: %w[string null], format: "email",
      )
    end

    it "accepts values in the format" do
      arguments = { born_on: "1990-12-10", email: "ada@example.com", visit_ids: [visit_id] }

      expect(params.validate(arguments)).must_equal arguments
    end

    it "accepts null for an optional field" do
      expect(params.validate({ born_on: "1990-12-10", visit_ids: [] })).must_equal(
        { born_on: "1990-12-10", email: nil, visit_ids: [] },
      )
    end

    it "rejects values outside the format" do
      error = expect do
        params.validate({ born_on: "1990-02-30", email: "N/A", visit_ids: [visit_id, "none"] })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal(
        "born_on must be a valid date; email must be a valid email; visit_ids[1] must be a valid uuid",
      )
    end

    it "rejects a value of the wrong type before checking the format" do
      error = expect { params.validate({ born_on: 19_901_210, visit_ids: [] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "born_on must be a string"
    end

    it "prefixes errors with the path of an enclosing object" do
      outer = Riffer::Params.new
      outer.required(:patient, :object) { required :born_on, :string, format: "date" }

      error = expect { outer.validate({ patient: { born_on: "soon" } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "patient.born_on must be a valid date"
    end

    it "checks the format inside an AnyOf variant" do
      outer = Riffer::Params.new
      outer.required(:contact, :any_of) do
        variant { required :email, :string, format: "email" }
        variant { required :phone, :string }
      end

      expect(outer.validate({ contact: { email: "ada@example.com" } })).must_equal(
        { contact: { email: "ada@example.com" } },
      )
      error = expect { outer.validate({ contact: { email: "N/A" } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/variant 1 \(email must be a valid email\)/)
    end

    it "reads the format back from the field and the items" do
      rebuilt = Riffer::Params.from_json_schema(params.to_json_schema)

      expect(rebuilt.parameters.map(&:format)).must_equal %w[date email uuid]
      error = expect { rebuilt.validate({ born_on: "soon", visit_ids: [] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "born_on must be a valid date"
    end

    it "raises when reading back a format on non-string items" do
      error = expect do
        Riffer::Params.from_json_schema(
          {
            type: "object",
            properties: { "counts" => { type: "array", items: { type: "integer", format: "date" } } },
            required: ["counts"],
          },
        )
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "counts: format: requires :string or an :array whose innermost type is :string"
    end

    it "round-trips losslessly with to_json_schema(strict: false)" do
      schema = params.to_json_schema(strict: false)

      expect(Riffer::Params.from_json_schema(schema).to_json_schema(strict: false)).must_equal schema
    end

    it "raises when reading back a format outside the supported list" do
      error = expect do
        Riffer::Params.from_json_schema(
          { type: "object", properties: { "count" => { type: "integer", format: "int32" } }, required: ["count"] },
        )
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/\Acount: format: must be a supported format \(.*\), got "int32"\z/)
    end
  end

  describe "Array of arrays" do
    let(:params) do
      params = Riffer::Params.new
      params.required(:grid, :array, of: [:integer], description: "Rows of cells")
      params.optional(:moves, :array, of: [[:string]], enum: %w[x o])
      params
    end

    it "raises ArgumentError with of: nesting no type or more than one" do
      [[], %i[integer string], [[]], [nil]].each do |of|
        error = expect { Riffer::Params.new.required(:grid, :array, of: of) }.must_raise(Riffer::ArgumentError)
        expect(error.message).must_match(/\Aof: must nest exactly one type, got /)
      end
    end

    it "raises ArgumentError with of: nesting a non-primitive type" do
      error = expect { Riffer::Params.new.required(:grid, :array, of: [:object]) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "of: must be one of :string, :integer, :number, :boolean, got :object"
    end

    it "raises ArgumentError with a nested of: on a non-Array type" do
      error = expect { Riffer::Params.new.required(:grid, :string, of: [:integer]) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "of: can only be used with :array, got :string"
    end

    it "renders one items level per array, with the enum on the innermost items" do
      expect(params.to_json_schema[:properties]).must_equal(
        "grid" => {
          type: "array", description: "Rows of cells", items: { type: "array", items: { type: "integer" } },
        },
        "moves" => {
          type: "array",
          items: { type: "array", items: { type: "array", items: { type: "string", enum: %w[x o] } } },
        },
      )
    end

    it "makes only the field nullable when optional in strict mode" do
      expect(params.to_json_schema(strict: true)[:properties]["moves"]).must_equal(
        type: %w[array null],
        items: { type: "array", items: { type: "array", items: { type: "string", enum: %w[x o] } } },
      )
    end

    it "renders the format on the innermost items" do
      params = Riffer::Params.new
      params.required(:visit_ids, :array, of: [:string], format: "uuid")

      expect(params.to_json_schema[:properties]["visit_ids"]).must_equal(
        type: "array", items: { type: "array", items: { type: "string", format: "uuid" } },
      )
    end

    it "accepts nested arrays, including empty ones" do
      arguments = { grid: [[1, 2], []], moves: [[%w[x o]], []] }

      expect(params.validate(arguments)).must_equal arguments
    end

    it "rejects an inner value that is not an array with its path" do
      error = expect { params.validate({ grid: [[1], 2] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "grid[1] must be an array"
    end

    it "rejects innermost items of the wrong type or outside the enum with their path" do
      error = expect do
        params.validate({ grid: [[1, "2"]], moves: [[%w[x z]]] })
      end.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "grid[0][1] must be a integer; moves[0][0][1] must be one of: x, o"
    end

    it "checks Boolean innermost items" do
      params = Riffer::Params.new
      params.required(:checks, :array, of: [:boolean])

      expect(params.to_json_schema[:properties]["checks"][:items]).must_equal(type: "array", items: { type: "boolean" })
      expect(params.validate({ checks: [[true, false]] })).must_equal({ checks: [[true, false]] })
      error = expect { params.validate({ checks: [[1]] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "checks[0][0] must be a boolean"
    end

    it "rejects innermost items outside the format with their path" do
      params = Riffer::Params.new
      params.required(:visit_ids, :array, of: [:string], format: "uuid")

      error = expect { params.validate({ visit_ids: [["visit-1"]] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "visit_ids[0][0] must be a valid uuid"
    end

    it "coerces integer items of a nested of: :number to floats" do
      params = Riffer::Params.new
      params.required(:points, :array, of: [:number])

      expect(params.validate({ points: [[1, 2.5]] })).must_equal({ points: [[1.0, 2.5]] })
    end

    it "prefixes errors with the path of an enclosing object" do
      outer = Riffer::Params.new
      outer.required(:board, :object) { required :grid, :array, of: [:integer] }

      error = expect { outer.validate({ board: { grid: [["x"]] } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "board.grid[0][0] must be a integer"
    end

    it "checks nested arrays inside an AnyOf variant" do
      outer = Riffer::Params.new
      outer.required(:result, :any_of) do
        variant { required :grid, :array, of: [:integer] }
        variant { required :error_code, :string }
      end

      expect(outer.validate({ result: { grid: [[1]] } })).must_equal({ result: { grid: [[1]] } })
      error = expect { outer.validate({ result: { grid: [1] } }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/variant 1 \(grid\[0\] must be an array\)/)
    end

    it "reads nested items back with the innermost enum" do
      rebuilt = Riffer::Params.from_json_schema(params.to_json_schema)

      expect(rebuilt.parameters.map { |param| [param.item_type, param.dimensions, param.enum] }).must_equal(
        [[:integer, 2, nil], [:string, 3, %w[x o]]],
      )
      error = expect { rebuilt.validate({ grid: [["1"]] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "grid[0][0] must be a integer"
    end

    it "reads the innermost format back" do
      params = Riffer::Params.new
      params.required(:visit_ids, :array, of: [:string], format: "uuid")
      rebuilt = Riffer::Params.from_json_schema(params.to_json_schema)

      expect(rebuilt.parameters.first.format).must_equal "uuid"
      error = expect { rebuilt.validate({ visit_ids: [["visit-1"]] }) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_equal "visit_ids[0][0] must be a valid uuid"
    end

    it "round-trips losslessly with to_json_schema(strict: false)" do
      schema = params.to_json_schema(strict: false)

      expect(Riffer::Params.from_json_schema(schema).to_json_schema(strict: false)).must_equal schema
    end

    it "raises when reading back an inner array without items, nullable, or with an enum or format" do
      [
        { type: "array" },
        { type: %w[array null], items: { type: "integer" } },
        { type: "array", enum: [[1]], items: { type: "integer" } },
        { type: "array", format: "date", items: { type: "string" } },
      ].each do |inner|
        error = expect do
          Riffer::Params.from_json_schema(
            { type: "object", properties: { "grid" => { type: "array", items: inner } }, required: ["grid"] },
          )
        end.must_raise(Riffer::ArgumentError)
        expect(error.message).must_equal "Unsupported nested array: #{inner.to_json}"
      end
    end

    it "raises when reading back an enum or format on the field of a nested array" do
      [
        { type: "array", enum: [[["x"]]], items: { type: "array", items: { type: "string", enum: ["x"] } } },
        { type: "array", format: "date", items: { type: "array", items: { type: "string" } } },
      ].each do |grid|
        error = expect do
          Riffer::Params.from_json_schema({ type: "object", properties: { "grid" => grid }, required: ["grid"] })
        end.must_raise(Riffer::ArgumentError)
        expect(error.message).must_equal "Unsupported nested array: #{grid.to_json}"
      end
    end

    it "raises when reading back innermost items that are objects or a union of types" do
      {
        { type: "object", properties: {} } => 'Unsupported nested array items: {"type":"object","properties":{}}',
        { type: %w[integer null] } => 'Unsupported nested array items: {"type":["integer","null"]}',
        { type: %w[string integer] } => 'Unsupported JSON Schema type: ["string", "integer"]',
      }.each do |leaf, message|
        grid = { type: "array", items: { type: "array", items: leaf } }

        error = expect do
          Riffer::Params.from_json_schema({ type: "object", properties: { "grid" => grid }, required: ["grid"] })
        end.must_raise(Riffer::ArgumentError)
        expect(error.message).must_equal message
      end
    end
  end
end
