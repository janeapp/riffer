# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::CallTool do
  def make_tool(name:, description: "desc", &call_body)
    n = name
    d = description
    body = call_body || ->(**kwargs) { Riffer::Tools::Response.text("called #{n} with #{kwargs.inspect}") }
    Class.new(Riffer::Tool) do
      @identifier = n
      define_singleton_method(:name) { n }
      define_singleton_method(:identifier) { n }
      define_singleton_method(:description) { d }
      define_singleton_method(:parameters_schema) { |strict: false| {type: "object", properties: {}, required: [], additionalProperties: false} }
      define_method(:call) { |context:, **kwargs| body.call(context: context, **kwargs) }
    end
  end

  let(:tool_a) { make_tool(name: "github__search") }
  let(:tool_b) { make_tool(name: "github__create_pr") }
  let(:context) { Riffer::Agent::Context.new.tap { |c| c.mcp_progressive_tools = [tool_a, tool_b] } }

  describe "class metadata" do
    it "has identifier mcp_call" do
      assert_equal "mcp_call", Riffer::Mcp::CallTool.identifier
    end

    it "marks tool_name as required and arguments as optional" do
      schema = Riffer::Mcp::CallTool.parameters_schema
      assert_includes schema[:required], "tool_name"
      refute_includes schema[:required], "arguments"
    end

    it "passes tool validation" do
      assert Riffer::Mcp::CallTool.validate_as_tool!
    end
  end

  describe "#call" do
    it "invokes the target tool and returns its response" do
      resp = Riffer::Mcp::CallTool.new.call(
        context: context,
        tool_name: "github__search",
        arguments: '{"q":"ruby"}'
      )
      assert resp.success?
      assert_includes resp.content, "called github__search"
    end

    it "passes parsed arguments as keyword args to the inner tool" do
      received = nil
      capturing = make_tool(name: "capture") do |context:, **kwargs|
        received = kwargs
        Riffer::Tools::Response.text("ok")
      end
      Riffer::Mcp::CallTool.new.call(
        context: Riffer::Agent::Context.new.tap { |c| c.mcp_progressive_tools = [capturing] },
        tool_name: "capture",
        arguments: '{"x":1,"y":"hello"}'
      )
      assert_equal({x: 1, y: "hello"}, received)
    end

    it "passes context through to the inner tool" do
      ctx_received = nil
      ctx_tool = make_tool(name: "ctx_tool") do |context:, **kwargs|
        ctx_received = context
        Riffer::Tools::Response.text("ok")
      end
      Riffer::Mcp::CallTool.new.call(
        context: Riffer::Agent::Context.new(tenant: "acme").tap { |c| c.mcp_progressive_tools = [ctx_tool] },
        tool_name: "ctx_tool"
      )
      assert_equal "acme", ctx_received[:tenant]
    end

    it "treats nil arguments as empty hash" do
      resp = Riffer::Mcp::CallTool.new.call(context: context, tool_name: "github__search", arguments: nil)
      assert resp.success?
    end

    it "treats empty string arguments as empty hash" do
      resp = Riffer::Mcp::CallTool.new.call(context: context, tool_name: "github__search", arguments: "")
      assert resp.success?
    end

    it "returns an error response when tool_name is not found" do
      resp = Riffer::Mcp::CallTool.new.call(context: context, tool_name: "nonexistent")
      assert resp.error?
      assert_includes resp.content, "not found"
    end

    it "returns an error response when tool_name is empty string" do
      resp = Riffer::Mcp::CallTool.new.call(context: context, tool_name: "")
      assert resp.error?
      assert_includes resp.content, "non-empty string"
    end

    it "returns an error response when context has no progressive tools" do
      resp = Riffer::Mcp::CallTool.new.call(context: Riffer::Agent::Context.new, tool_name: "github__search")
      assert resp.error?
      assert_includes resp.content, "not found"
    end

    it "returns an error response when arguments is valid JSON but not an object" do
      resp = Riffer::Mcp::CallTool.new.call(
        context: context,
        tool_name: "github__search",
        arguments: '"just a string"'
      )
      assert resp.error?
      assert_includes resp.content, "JSON object"
    end

    it "returns an error response for malformed JSON arguments" do
      resp = Riffer::Mcp::CallTool.new.call(
        context: context,
        tool_name: "github__search",
        arguments: "{not valid json"
      )
      assert resp.error?
      assert_includes resp.content, "Invalid JSON"
    end

    it "returns an error response when inner tool raises ArgumentError (missing keyword)" do
      strict = make_tool(name: "strict_tool") do |context:, required_key:|
        Riffer::Tools::Response.text("ok #{required_key}")
      end
      resp = Riffer::Mcp::CallTool.new.call(
        context: Riffer::Agent::Context.new.tap { |c| c.mcp_progressive_tools = [strict] },
        tool_name: "strict_tool",
        arguments: "{}"
      )
      assert resp.error?
      assert_includes resp.content, "Argument error"
    end

    it "forwards error responses from inner tools" do
      failing = make_tool(name: "failing") do |context:, **kwargs|
        Riffer::Tools::Response.error("inner error")
      end
      resp = Riffer::Mcp::CallTool.new.call(
        context: Riffer::Agent::Context.new.tap { |c| c.mcp_progressive_tools = [failing] },
        tool_name: "failing"
      )
      assert resp.error?
      assert_includes resp.content, "inner error"
    end
  end

  describe "#call_with_validation" do
    it "raises a validation error when tool_name is nil" do
      assert_raises(Riffer::ValidationError) do
        Riffer::Mcp::CallTool.new.call_with_validation(context: context, tool_name: nil)
      end
    end
  end
end
