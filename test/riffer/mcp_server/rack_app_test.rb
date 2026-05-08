# frozen_string_literal: true

require "test_helper"
require "rack"
require "mcp"
require_relative "../../fixtures/tools/ping_tool"

describe Riffer::McpServer::RackApp do
  let(:registry) { Riffer::McpServer::Registry.new }
  let(:config) { Riffer::McpServer::Config.new(registry: registry) }
  let(:app) { Riffer::McpServer::RackApp.build(config: config, registry: registry) }

  before do
    config.authenticator = ->(t) { (t == "good") ? :token_object : nil }
  end

  def post_jsonrpc(payload, authorization: "Bearer good")
    body = JSON.generate(payload)
    headers = {
      "CONTENT_TYPE" => "application/json",
      "HTTP_ACCEPT" => "application/json"
    }
    headers["HTTP_AUTHORIZATION"] = authorization if authorization
    Rack::MockRequest.new(app).post("/", input: body, **headers)
  end

  def jsonrpc_envelope(method, params = {}, id: 1)
    {jsonrpc: "2.0", id: id, method: method, params: params}
  end

  def parse(response)
    JSON.parse(response.body, symbolize_names: true)
  end

  describe "authentication" do
    it "returns 401 when the Authorization header is missing" do
      response = post_jsonrpc(jsonrpc_envelope("tools/list"), authorization: nil)
      assert_equal 401, response.status
    end

    it "returns 401 when the bearer token is invalid" do
      response = post_jsonrpc(jsonrpc_envelope("tools/list"), authorization: "Bearer bad")
      assert_equal 401, response.status
    end
  end

  describe "tools/list" do
    before { config.expose(Test::PingTool) }

    it "returns the registered tools with their schemas" do
      response = post_jsonrpc(jsonrpc_envelope("tools/list"))
      assert_equal 200, response.status

      tools = parse(response).dig(:result, :tools)
      assert_equal 1, tools.size
      assert_equal "ping_tool", tools.first[:name]
      assert_equal Test::PingTool.description, tools.first[:description]
      assert_includes tools.first.dig(:inputSchema, :properties).keys, :message
    end
  end

  describe "tools/call" do
    before { config.expose(Test::PingTool) }

    it "dispatches the call and returns the tool's text content" do
      response = post_jsonrpc(jsonrpc_envelope("tools/call", {name: "ping_tool", arguments: {message: "hello"}}))
      assert_equal 200, response.status

      content = parse(response).dig(:result, :content)
      refute_nil content
      assert_equal "hello", content.first[:text]
      refute parse(response).dig(:result, :isError)
    end

    it "surfaces a missing-argument validation failure as a JSON-RPC -32602 error" do
      response = post_jsonrpc(jsonrpc_envelope("tools/call", {name: "ping_tool", arguments: {}}))
      assert_equal 200, response.status

      parsed = parse(response)
      assert_nil parsed[:result]
      assert_equal(-32_602, parsed.dig(:error, :code))
      assert_match(/message/i, parsed.dig(:error, :data).to_s)
    end
  end

  describe "context_builder threading" do
    let(:reveal_tool_class) do
      Class.new(Riffer::Tool) do
        identifier "reveal_ctx"
        description "Reveals the per-request context"
        def call(context:)
          text(context.inspect)
        end
      end
    end

    it "passes the context_builder's output through to the tool" do
      config.context_builder = ->(token) { {token_role: token} }
      config.expose(reveal_tool_class)

      response = post_jsonrpc(jsonrpc_envelope("tools/call", {name: "reveal_ctx", arguments: {}}))
      assert_equal 200, response.status

      text = parse(response).dig(:result, :content, 0, :text)
      assert_match(/token_role/, text)
      assert_match(/token_object/, text)
    end
  end
end
