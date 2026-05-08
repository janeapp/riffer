# frozen_string_literal: true

require "test_helper"
require "mcp"
require_relative "../../fixtures/tools/ping_tool"

describe Riffer::McpServer::ToolAdapter do
  let(:adapter_class) { Riffer::McpServer::ToolAdapter.build_for(Test::PingTool) }

  def server_context_double(context_hash)
    Struct.new(:context) do
      def [](key)
        context[key]
      end
    end.new(context_hash)
  end

  describe ".build_for" do
    it "returns a subclass of MCP::Tool" do
      assert_operator adapter_class, :<, MCP::Tool
    end

    it "carries the tool's name forward as MCP tool_name" do
      assert_equal "ping_tool", adapter_class.tool_name
    end

    it "carries the tool's description forward" do
      assert_equal Test::PingTool.description, adapter_class.description_value
    end

    it "produces an MCP-compatible input_schema with the tool's strict schema" do
      schema = adapter_class.input_schema_value.to_h
      assert_includes schema[:properties].keys, :message
      assert_includes schema[:required], "message"
    end
  end

  describe ".call" do
    it "dispatches the success path and returns an MCP::Tool::Response" do
      response = adapter_class.call(server_context: server_context_double({}), message: "hello")
      assert_kind_of MCP::Tool::Response, response
      refute_predicate response, :error?
      assert_equal "hello", response.content.first[:text]
      assert_equal "text", response.content.first[:type]
    end

    it "passes the riffer context through to the underlying tool" do
      reveal_tool_class = Class.new(Riffer::Tool) do
        identifier "reveal_context"
        description "Reveals the per-request context"
        def call(context:)
          text(context.inspect)
        end
      end

      reveal_adapter = Riffer::McpServer::ToolAdapter.build_for(reveal_tool_class)
      ctx = {tenant_id: "abc"}
      response = reveal_adapter.call(server_context: server_context_double({riffer_context: ctx}))
      assert_match(/tenant_id/, response.content.first[:text])
    end

    it "uses an empty hash when server_context is nil" do
      empty_tool_class = Class.new(Riffer::Tool) do
        identifier "empty_ctx"
        description "Returns context inspect"
        def call(context:)
          text(context.inspect)
        end
      end

      response = Riffer::McpServer::ToolAdapter.build_for(empty_tool_class).call(server_context: nil)
      assert_equal "{}", response.content.first[:text]
    end

    it "converts Riffer::ValidationError into an error MCP::Tool::Response with the message" do
      response = adapter_class.call(server_context: server_context_double({}))
      assert_predicate response, :error?
      assert_match(/message is required/, response.content.first[:text])
    end

    it "converts Riffer::TimeoutError into an error response that mentions the timeout" do
      slow_tool_class = Class.new(Riffer::Tool) do
        identifier "slow_tool"
        description "Sleeps forever"
        timeout 0.05
        def call(context:)
          sleep 1
          text("never")
        end
      end

      response = Riffer::McpServer::ToolAdapter.build_for(slow_tool_class).call(server_context: server_context_double({}))
      assert_predicate response, :error?
      assert_match(/timed out/i, response.content.first[:text])
    end

    it "converts a generic StandardError into an error response without leaking the backtrace" do
      explosion = Class.new(Riffer::Tool) do
        identifier "kaboom"
        description "Raises"
        def call(context:)
          raise "kaboom-detail"
        end
      end

      response = Riffer::McpServer::ToolAdapter.build_for(explosion).call(server_context: server_context_double({}))
      assert_predicate response, :error?
      text = response.content.first[:text]
      assert_match(/kaboom-detail/, text)
      refute_match(/tool_adapter\.rb/, text, "backtrace should not leak into the response body")
    end

    it "raises ArgumentError when the source tool has no description (MCP requires it)" do
      bare = Class.new(Riffer::Tool) do
        identifier "bare"
      end
      assert_raises(Riffer::ArgumentError) do
        Riffer::McpServer::ToolAdapter.build_for(bare)
      end
    end

    it "treats a server_context with no :riffer_context key as an empty context" do
      reveal = Class.new(Riffer::Tool) do
        identifier "no_riffer_ctx"
        description "Inspects context"
        def call(context:)
          text(context.inspect)
        end
      end
      response = Riffer::McpServer::ToolAdapter.build_for(reveal).call(server_context: server_context_double({other: :stuff}))
      assert_equal "{}", response.content.first[:text]
    end
  end

  describe ".sanitize_schema_for_mcp" do
    it "returns the schema unchanged when :required is non-empty" do
      schema = {type: "object", required: ["x"]}
      assert_equal schema, Riffer::McpServer::ToolAdapter.sanitize_schema_for_mcp(schema)
    end

    it "drops :required when it is an empty array" do
      schema = {type: "object", properties: {}, required: [], additionalProperties: false}
      cleaned = Riffer::McpServer::ToolAdapter.sanitize_schema_for_mcp(schema)
      refute_includes cleaned.keys, :required
    end

    it "returns the input unchanged when it is not a Hash" do
      assert_equal "not-a-hash", Riffer::McpServer::ToolAdapter.sanitize_schema_for_mcp("not-a-hash")
    end

    it "returns the schema unchanged when :required is not an Array" do
      schema = {type: "object", required: nil}
      assert_equal schema, Riffer::McpServer::ToolAdapter.sanitize_schema_for_mcp(schema)
    end
  end
end
