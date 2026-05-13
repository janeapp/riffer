# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::SearchTool do
  def make_tool(name:, description:, schema: nil)
    n = name
    d = description
    s = schema || {type: "object", properties: {}, required: [], additionalProperties: false}
    Class.new(Riffer::Tool) do
      @identifier = n
      define_singleton_method(:name) { n }
      define_singleton_method(:identifier) { n }
      define_singleton_method(:description) { d }
      define_singleton_method(:parameters_schema) { |strict: false| s }
      define_method(:call) { |context:, **kwargs| text("called #{n} with #{kwargs.inspect}") }
    end
  end

  let(:tool_a) { make_tool(name: "github__search", description: "Search GitHub repos") }
  let(:tool_b) { make_tool(name: "github__create_pr", description: "Create a pull request") }
  let(:context) { {mcp_progressive_tools: [tool_a, tool_b]} }

  describe "class metadata" do
    it "has identifier mcp_search" do
      assert_equal "mcp_search", Riffer::Mcp::SearchTool.identifier
    end

    it "marks query as required in the schema" do
      schema = Riffer::Mcp::SearchTool.parameters_schema
      assert_includes schema[:required], "query"
    end

    it "passes tool validation" do
      assert Riffer::Mcp::SearchTool.validate_as_tool!
    end
  end

  describe "#call" do
    it "returns all tools when query is empty string" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "")
      assert resp.success?
      assert_includes resp.content, "github__search"
      assert_includes resp.content, "github__create_pr"
    end

    it "filters by name substring" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "search")
      assert_includes resp.content, "github__search"
      refute_includes resp.content, "github__create_pr"
    end

    it "filters case-insensitively" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "SEARCH")
      assert_includes resp.content, "github__search"
      refute_includes resp.content, "github__create_pr"
    end

    it "filters by description substring" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "pull request")
      assert_includes resp.content, "github__create_pr"
      refute_includes resp.content, "github__search"
    end

    it "returns a not-found message with the query when no tools match" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "zzznomatch")
      assert resp.success?
      assert_includes resp.content, "No tools found matching 'zzznomatch'"
    end

    it "returns a no-tools message when the context has an empty tools list" do
      resp = Riffer::Mcp::SearchTool.new.call(context: {mcp_progressive_tools: []}, query: "")
      assert resp.success?
      assert_includes resp.content, "No tools available"
    end

    it "returns a no-tools message when context is missing the key" do
      resp = Riffer::Mcp::SearchTool.new.call(context: {}, query: "")
      assert resp.success?
      assert_includes resp.content, "No tools available"
    end

    it "returns a no-tools message when context is nil" do
      resp = Riffer::Mcp::SearchTool.new.call(context: nil, query: "")
      assert resp.success?
      assert_includes resp.content, "No tools available"
    end

    it "includes the tool schema in output" do
      tool_with_schema = make_tool(
        name: "srv__fetch",
        description: "Fetch a URL",
        schema: {type: "object", properties: {"url" => {type: "string"}}, required: ["url"], additionalProperties: false}
      )
      resp = Riffer::Mcp::SearchTool.new.call(context: {mcp_progressive_tools: [tool_with_schema]}, query: "")
      assert_includes resp.content, '"url"'
    end
  end

  describe "#call_with_validation" do
    it "raises a validation error when query is nil" do
      assert_raises(Riffer::ValidationError) do
        Riffer::Mcp::SearchTool.new.call_with_validation(context: context, query: nil)
      end
    end
  end
end
