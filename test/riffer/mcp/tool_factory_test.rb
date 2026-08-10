# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::ToolFactory do
  let(:schema) do
    { type: "object", properties: { query: { type: "string" } }, required: ["query"], additionalProperties: false }
  end

  let(:tool_defs) do
    [
      { name: "search", description: "Search the web", input_schema: schema },
      { name: "calculator", description: "Do math", input_schema: nil },
    ]
  end

  let(:fake_client) do
    client = Object.new
    client.define_singleton_method(:tools_call) { |name, _args| "result from #{name}" }
    client
  end

  let(:tool_classes) { Riffer::Mcp::ToolFactory.build("srv", fake_client, tool_defs) }

  describe ".build" do
    it "returns one class per tool definition" do
      assert_equal 2, tool_classes.size
    end

    it "returns Riffer::Mcp::Tool subclasses" do
      tool_classes.each { |klass| assert_operator klass, :<, Riffer::Mcp::Tool }
    end
  end

  describe "generated tool class" do
    let(:search_class) { tool_classes.first }

    describe ".name" do
      it "returns the prefixed tool name" do
        assert_equal "srv__search", search_class.name
      end
    end

    describe ".mcp_server_tool_name" do
      it "returns the original MCP server tool name" do
        assert_equal "search", search_class.mcp_server_tool_name
      end
    end

    describe ".description" do
      it "returns the MCP tool description" do
        assert_equal "Search the web", search_class.description
      end
    end

    describe ".identifier" do
      it "returns the prefixed name without falling back to class path" do
        assert_equal "srv__search", search_class.identifier
      end
    end

    describe ".parameters_schema" do
      it "returns the MCP input_schema unchanged" do
        assert_equal schema, search_class.parameters_schema
      end

      it "returns empty schema when input_schema is nil" do
        calc_class = tool_classes.last
        result = calc_class.parameters_schema

        assert_equal "object", result[:type]
        assert_empty result[:properties]
      end

      it "ignores the strict: keyword and does not transform the schema" do
        assert_equal schema, search_class.parameters_schema(strict: true)
      end
    end

    describe "#call" do
      it "delegates to the MCP client and returns a text response" do
        tool = search_class.new
        result = tool.call(context: nil, query: "ruby")

        assert_instance_of Riffer::Tools::Response, result
        assert_equal "result from search", result.content
      end

      it "passes kwargs as arguments to tools_call" do
        received_args = nil
        client = Object.new
        client.define_singleton_method(:tools_call) do |_name, args|
          received_args = args
          "ok"
        end
        klass = Riffer::Mcp::ToolFactory.build(
          "srv",
          client,
          [{ name: "t", description: "T", input_schema: nil }],
        ).first
        klass.new.call(context: nil, key: "value")

        assert_equal({ key: "value" }, received_args)
      end
    end
  end

  describe "name sanitization" do
    it "replaces spaces and special characters with underscores" do
      tools = Riffer::Mcp::ToolFactory.build(
        "my server!",
        fake_client,
        [{ name: "get items", description: "G", input_schema: nil }],
      )

      assert_equal "my_server___get_items", tools.first.name
    end

    it "preserves hyphens and underscores" do
      tools = Riffer::Mcp::ToolFactory.build(
        "my-srv_1",
        fake_client,
        [{ name: "get-items_v2", description: "G", input_schema: nil }],
      )

      assert_equal "my-srv_1__get-items_v2", tools.first.name
    end
  end
end
