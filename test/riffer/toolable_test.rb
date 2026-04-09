# frozen_string_literal: true

require "test_helper"

describe Riffer::Toolable do
  let(:toolable_class) do
    Class.new do
      extend Riffer::Toolable

      description "A test toolable"

      params do
        required :input, String, description: "The input"
        optional :flag, String, default: "on"
      end
    end
  end

  describe ".all" do
    it "includes classes that extended Toolable" do
      expect(Riffer::Toolable.all).must_include Riffer::Tool
    end
  end

  describe "#description" do
    it "sets and gets the description" do
      expect(toolable_class.description).must_equal "A test toolable"
    end

    it "returns nil when not set" do
      klass = Class.new { extend Riffer::Toolable }
      expect(klass.description).must_be_nil
    end
  end

  describe "#identifier" do
    it "can be set explicitly" do
      klass = Class.new { extend Riffer::Toolable }
      klass.identifier("custom_id")
      expect(klass.identifier).must_equal "custom_id"
    end
  end

  describe "#name" do
    it "is an alias for identifier" do
      klass = Class.new { extend Riffer::Toolable }
      klass.identifier("my_tool")
      expect(klass.name).must_equal "my_tool"
    end
  end

  describe "#timeout" do
    it "returns DEFAULT_TIMEOUT when not set" do
      klass = Class.new { extend Riffer::Toolable }
      expect(klass.timeout).must_equal 10
    end

    it "sets the timeout value" do
      klass = Class.new do
        extend Riffer::Toolable

        timeout 30
      end
      expect(klass.timeout).must_equal 30.0
    end

    it "converts to float" do
      klass = Class.new do
        extend Riffer::Toolable

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
      klass = Class.new { extend Riffer::Toolable }
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
      klass = Class.new { extend Riffer::Toolable }
      schema = klass.parameters_schema
      expect(schema[:type]).must_equal "object"
      expect(schema[:properties]).must_equal({})
    end
  end

  describe "#requires_approval" do
    it "defaults to false" do
      klass = Class.new { extend Riffer::Toolable }
      expect(klass.requires_approval).must_equal false
    end

    it "can be set to true" do
      klass = Class.new do
        extend Riffer::Toolable

        requires_approval true
      end
      expect(klass.requires_approval).must_equal true
    end
  end

  describe "#kind" do
    it "defaults to :tool" do
      klass = Class.new { extend Riffer::Toolable }
      expect(klass.kind).must_equal :tool
    end

    it "can be set to a custom value" do
      klass = Class.new do
        extend Riffer::Toolable

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
      klass = Class.new { extend Riffer::Toolable }
      expect { klass.validate_as_tool! }.must_raise(Riffer::ArgumentError)
    end

    it "succeeds when description and identifier are present" do
      klass = Class.new do
        extend Riffer::Toolable

        description "Valid tool"
      end
      klass.identifier("valid_tool")
      expect(klass.validate_as_tool!).must_equal true
    end
  end
end
