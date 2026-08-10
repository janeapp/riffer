# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::Tool do
  describe ".mcp_server_tool_name" do
    it "returns the value set on the subclass" do
      klass = Class.new(Riffer::Mcp::Tool) { @mcp_server_tool_name = "search" }

      assert_equal "search", klass.mcp_server_tool_name
    end

    it "raises NotImplementedError when unset" do
      klass = Class.new(Riffer::Mcp::Tool)
      assert_raises(NotImplementedError) { klass.mcp_server_tool_name }
    end
  end

  describe ".parameters_schema" do
    let(:schema) do
      { type: "object", properties: { query: { type: "string" } }, required: ["query"], additionalProperties: false }
    end

    it "returns the input schema set on the subclass" do
      input_schema = schema
      klass = Class.new(Riffer::Mcp::Tool) { @input_schema = input_schema }

      assert_equal schema, klass.parameters_schema
    end

    it "falls back to the params DSL when no input schema is set" do
      klass = Class.new(Riffer::Mcp::Tool) do
        params { required :city, String }
      end

      assert_equal ["city"], klass.parameters_schema[:required]
    end

    it "falls back to the empty schema when neither is set" do
      klass = Class.new(Riffer::Mcp::Tool)

      assert_empty klass.parameters_schema[:properties]
    end
  end
end
