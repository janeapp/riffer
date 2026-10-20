# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Toolable do
  let(:toolable_class) do
    Class.new do
      extend Riffer::Tools::Toolable

      description "A test toolable"

      params do
        required :input, String, description: "The input"
        optional :flag, String, default: "on"
      end
    end
  end

  describe ".all" do
    it "includes classes that extended Toolable" do
      expect(Riffer::Tools::Toolable.all).must_include Riffer::Tool
    end
  end

  describe "#description" do
    it "sets and gets the description" do
      expect(toolable_class.description).must_equal "A test toolable"
    end

    it "returns nil when not set" do
      klass = Class.new { extend Riffer::Tools::Toolable }

      expect(klass.description).must_be_nil
    end
  end

  describe "#identifier" do
    it "can be set explicitly" do
      klass = Class.new { extend Riffer::Tools::Toolable }
      klass.identifier("custom_id")

      expect(klass.identifier).must_equal "custom_id"
    end
  end

  describe "#name" do
    it "is an alias for identifier" do
      klass = Class.new { extend Riffer::Tools::Toolable }
      klass.identifier("my_tool")

      expect(klass.name).must_equal "my_tool"
    end
  end

  describe "#timeout" do
    it "returns DEFAULT_TIMEOUT when not set" do
      klass = Class.new { extend Riffer::Tools::Toolable }

      expect(klass.timeout).must_equal 10
    end

    it "sets the timeout value" do
      klass = Class.new do
        extend Riffer::Tools::Toolable

        timeout 30
      end

      expect(klass.timeout).must_equal 30.0
    end

    it "converts to float" do
      klass = Class.new do
        extend Riffer::Tools::Toolable

        timeout 15
      end

      expect(klass.timeout).must_be_instance_of Float
    end
  end

  describe "#params" do
    it "returns the params builder" do
      expect(toolable_class.params).must_be_instance_of Riffer::Params
    end

    it "returns nil when no params defined" do
      klass = Class.new { extend Riffer::Tools::Toolable }

      expect(klass.params).must_be_nil
    end
  end

  describe "#parameters_schema" do
    it "returns JSON schema for params" do
      schema = toolable_class.parameters_schema

      expect(schema[:type]).must_equal "object"
      expect(schema[:properties].key?("input")).must_equal true
      expect(schema[:required]).must_include "input"
    end

    it "returns empty schema when no params defined" do
      klass = Class.new { extend Riffer::Tools::Toolable }
      schema = klass.parameters_schema

      expect(schema[:type]).must_equal "object"
      expect(schema[:properties]).must_equal({})
    end

    describe "with a Hash param that has no block" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "apply_rule"
          description "Applies a rule"

          params do
            required :applies_when, Hash
          end
        end
      end

      it "raises ArgumentError in strict mode" do
        error = expect { tool_class.parameters_schema(strict: true) }.must_raise(Riffer::ArgumentError)

        expect(error.message).must_equal(
          "applies_when: a Hash param requires a block defining its properties under strict schemas",
        )
      end

      it "renders the schema in non-strict mode" do
        expect(tool_class.parameters_schema[:properties]["applies_when"]).must_equal(type: "object")
      end
    end

    describe "with an AnyOf param" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "find_patient"
          description "Finds a patient"

          params do
            required :lookup, Riffer::Params::AnyOf do
              variant { required :email, String }
              variant { required :phone, String }
            end
          end
        end
      end

      it "renders each variant in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["lookup"]).must_equal(
          anyOf: [
            {
              type: "object",
              properties: { "email" => { type: "string" } },
              required: ["email"],
              additionalProperties: false,
            },
            {
              type: "object",
              properties: { "phone" => { type: "string" } },
              required: ["phone"],
              additionalProperties: false,
            },
          ],
        )
      end
    end

    describe "with an array of enum values" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "tag_ticket"
          description "Tags a ticket"

          params do
            required :tags, Array, of: String, enum: %w[urgent billing]
          end
        end
      end

      it "renders the enum on the items in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["tags"]).must_equal(
          type: "array", items: { type: "string", enum: %w[urgent billing] },
        )
      end
    end

    describe "with a format" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "book_visit"
          description "Books a visit"

          params do
            optional :on, String, format: "date"
          end
        end
      end

      it "renders the format next to the nullable type in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["on"]).must_equal(
          type: %w[string null], format: "date",
        )
      end
    end

    describe "with an array of arrays" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "plot_route"
          description "Plots a route"

          params do
            optional :points, Array, of: [Float]
          end
        end
      end

      it "makes only the field nullable in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["points"]).must_equal(
          type: %w[array null], items: { type: "array", items: { type: "number" } },
        )
      end
    end
  end

  describe "#kind" do
    it "defaults to :tool" do
      klass = Class.new { extend Riffer::Tools::Toolable }

      expect(klass.kind).must_equal :tool
    end

    it "can be set to a custom value" do
      klass = Class.new do
        extend Riffer::Tools::Toolable

        kind :agent
      end

      expect(klass.kind).must_equal :agent
    end
  end

  describe "#to_tool_schema" do
    it "returns a provider-agnostic schema hash" do
      toolable_class.identifier("test_tool")
      schema = toolable_class.to_tool_schema

      expect(schema[:name]).must_equal "test_tool"
      expect(schema[:description]).must_equal "A test toolable"
      expect(schema[:parameters_schema][:type]).must_equal "object"
    end

    it "passes strict option through" do
      schema = toolable_class.to_tool_schema(strict: true)

      expect(schema[:parameters_schema][:required]).must_include "flag"
    end
  end

  describe "#validate_as_tool!" do
    it "raises when description is missing" do
      klass = Class.new { extend Riffer::Tools::Toolable }

      expect { klass.validate_as_tool! }.must_raise(Riffer::ArgumentError)
    end

    it "succeeds when description and identifier are present" do
      klass = Class.new do
        extend Riffer::Tools::Toolable

        description "Valid tool"
      end
      klass.identifier("valid_tool")

      expect(klass.validate_as_tool!).must_equal true
    end
  end
end
