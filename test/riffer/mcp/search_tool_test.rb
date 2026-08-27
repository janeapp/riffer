# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::SearchTool do
  def make_tool(name:, description:)
    n = name
    d = description
    Class.new(Riffer::Tool) do
      @identifier = n
      define_singleton_method(:name) { n }
      define_singleton_method(:identifier) { n }
      define_singleton_method(:description) { d }
      define_singleton_method(:parameters_schema) do |strict: false|
        { type: "object", properties: {}, required: [], additionalProperties: false }
      end
      define_method(:call) { |context:, **_kwargs| text("called #{n}") }
    end
  end

  let(:tool_a) { make_tool(name: "github__search", description: "Search GitHub repos") }
  let(:tool_b) { make_tool(name: "github__create_pr", description: "Create a pull request") }
  let(:context) { Riffer::Agent::Context.new.tap { |c| c.mcp_progressive_tools = [tool_a, tool_b] } }

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

  describe "Result" do
    it "is a Riffer::Tools::Response subclass" do
      assert_operator Riffer::Mcp::SearchTool::Result, :<, Riffer::Tools::Response
    end

    it "is a success response" do
      result = Riffer::Mcp::SearchTool::Result.new("found it", [tool_a])

      assert_predicate result, :success?
    end

    it "carries discovered_tools" do
      result = Riffer::Mcp::SearchTool::Result.new("found it", [tool_a])

      assert_equal [tool_a], result.discovered_tools
    end
  end

  describe "#call" do
    it "returns an error when query is empty string" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "")

      assert_predicate resp, :error?
      assert_includes resp.content, "Provide a search query"
    end

    it "returns an error when query is whitespace only" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "  ")

      assert_predicate resp, :error?
      assert_includes resp.content, "Provide a search query"
    end

    it "returns a Result with matching tools as discovered_tools" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "search")

      assert_instance_of Riffer::Mcp::SearchTool::Result, resp
      assert_equal [tool_a], resp.discovered_tools
    end

    it "returns an acknowledgment naming the matched tools" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "search")

      assert_includes resp.content, "github__search"
      assert_includes resp.content, "call them directly"
    end

    it "filters by name substring" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "search")

      assert_equal [tool_a], resp.discovered_tools
      refute_includes resp.discovered_tools, tool_b
    end

    it "filters case-insensitively" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "SEARCH")

      assert_equal [tool_a], resp.discovered_tools
    end

    it "filters by description substring" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "pull request")

      assert_equal [tool_b], resp.discovered_tools
    end

    it "does not write to context (injection is the loop's responsibility)" do
      Riffer::Mcp::SearchTool.new.call(context: context, query: "search")

      assert_nil context.discovered_tools
    end

    it "returns a plain Response (not a Result) when no tools match" do
      resp = Riffer::Mcp::SearchTool.new.call(context: context, query: "zzznomatch")

      assert_instance_of Riffer::Tools::Response, resp
      refute_instance_of Riffer::Mcp::SearchTool::Result, resp
      assert_includes resp.content, "No tools found matching 'zzznomatch'"
    end

    it "returns not-found when the context has an empty tools list" do
      resp = Riffer::Mcp::SearchTool.new.call(
        context: Riffer::Agent::Context.new.tap { |c| c.mcp_progressive_tools = [] },
        query: "anything",
      )

      assert_predicate resp, :success?
      assert_includes resp.content, "No tools found"
    end

    it "returns not-found when context has no progressive tools" do
      resp = Riffer::Mcp::SearchTool.new.call(context: Riffer::Agent::Context.new, query: "anything")

      assert_predicate resp, :success?
      assert_includes resp.content, "No tools found"
    end

    it "returns not-found when context is nil" do
      resp = Riffer::Mcp::SearchTool.new.call(context: nil, query: "anything")

      assert_predicate resp, :success?
      assert_includes resp.content, "No tools found"
    end
  end

  describe "#call_with_validation" do
    it "returns a validation error response when query is nil" do
      response = Riffer::Mcp::SearchTool.new.call_with_validation(context: context, query: nil)

      assert_predicate response, :error?
      assert_equal :validation_error, response.error_type
    end
  end
end
