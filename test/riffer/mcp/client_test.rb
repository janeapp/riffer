# frozen_string_literal: true

require "test_helper"
require "mcp"

describe Riffer::Mcp::Client do
  # Build a Riffer::Mcp::Client with a pre-constructed fake inner MCP::Client,
  # bypassing real HTTP transport.
  def build_client(inner_client, endpoint: "https://example.com/mcp")
    Riffer::Mcp::Client.new(endpoint: endpoint, client: inner_client)
  end

  describe "#initialize" do
    it "uses an injected inner client when provided" do
      inner = Object.new
      inner.define_singleton_method(:tools) { [] }
      client = Riffer::Mcp::Client.new(endpoint: "https://x.com", client: inner)
      assert_equal [], client.tools_list
    end

    it "accepts Proc headers (resolved when building the real transport)" do
      # Verify that a Proc value is accepted without raising.
      # Header resolution is exercised in the transport construction path;
      # the injected-client path bypasses it, but the interface still accepts it.
      proc_headers = -> { {"Authorization" => "Bearer resolved"} }
      inner = Object.new
      inner.define_singleton_method(:tools) { [] }
      client = Riffer::Mcp::Client.new(endpoint: "https://x.com", headers: proc_headers, client: inner)
      assert_equal [], client.tools_list
    end
  end

  describe "#tools_list" do
    it "returns an array of hashes with :name, :description, :input_schema" do
      schema = {type: "object", properties: {}, required: [], additionalProperties: false}
      tool = MCP::Client::Tool.new(name: "search", description: "Search the web", input_schema: schema)
      inner = Object.new
      inner.define_singleton_method(:tools) { [tool] }

      result = build_client(inner).tools_list

      assert_equal 1, result.size
      assert_equal "search", result.first[:name]
      assert_equal "Search the web", result.first[:description]
      assert_equal schema, result.first[:input_schema]
    end

    it "returns an empty array when the server has no tools" do
      inner = Object.new
      inner.define_singleton_method(:tools) { [] }
      assert_empty build_client(inner).tools_list
    end
  end

  describe "#tools_call" do
    it "joins and returns text content from the response" do
      inner = Object.new
      inner.define_singleton_method(:call_tool) do |tool:, arguments:|
        {"result" => {"content" => [{"type" => "text", "text" => "Hello"}, {"type" => "text", "text" => " world"}]}}
      end

      result = build_client(inner).tools_call("greet", {name: "Alice"})
      assert_equal "Hello world", result
    end

    it "returns empty string when content array is empty" do
      inner = Object.new
      inner.define_singleton_method(:call_tool) { |**| {"result" => {"content" => []}} }
      assert_equal "", build_client(inner).tools_call("noop")
    end

    it "skips non-text content items" do
      inner = Object.new
      inner.define_singleton_method(:call_tool) do |**|
        {"result" => {"content" => [{"type" => "image", "data" => "..."}, {"type" => "text", "text" => "ok"}]}}
      end
      assert_equal "ok", build_client(inner).tools_call("img_tool")
    end

    it "passes the tool name and arguments to the inner client" do
      received_name = nil
      received_args = nil
      inner = Object.new
      inner.define_singleton_method(:call_tool) do |tool:, arguments:|
        received_name = tool.name
        received_args = arguments
        {"result" => {"content" => []}}
      end

      build_client(inner).tools_call("do_thing", {param: "val"})

      assert_equal "do_thing", received_name
      assert_equal({param: "val"}, received_args)
    end

    it "raises Riffer::Error when the inner client returns a JSON-RPC error (string keys)" do
      inner = Object.new
      inner.define_singleton_method(:call_tool) { |**| {"error" => {"message" => "bad request"}} }

      err = assert_raises(Riffer::Error) { build_client(inner).tools_call("x") }
      assert_equal "bad request", err.message
    end

    it "raises Riffer::Error when result.isError is true (string keys)" do
      inner = Object.new
      inner.define_singleton_method(:call_tool) do |**|
        {"result" => {"isError" => true, "content" => [{"type" => "text", "text" => "oops"}]}}
      end

      err = assert_raises(Riffer::Error) { build_client(inner).tools_call("x") }
      assert_equal "oops", err.message
    end
  end
end
