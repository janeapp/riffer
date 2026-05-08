# frozen_string_literal: true

require "test_helper"
require_relative "../fixtures/tools/ping_tool"

describe Riffer::McpServer do
  before { Riffer::McpServer.reset! }
  after { Riffer::McpServer.reset! }

  describe ".configure" do
    it "yields a Config object that exposes tools through the registry" do
      Riffer::McpServer.configure do |s|
        s.expose Test::PingTool
        s.authenticator = ->(_t) { Object.new }
      end

      assert_equal Test::PingTool, Riffer::McpServer.registry.lookup("ping_tool")[:tool_class]
      refute_nil Riffer::McpServer.config.authenticator
    end

    it "accumulates configuration across multiple configure calls" do
      Riffer::McpServer.configure { |s| s.expose Test::PingTool, scope: :alpha }
      Riffer::McpServer.configure { |s| s.expose Test::PingTool, scope: :beta }
      assert_equal 2, Riffer::McpServer.registry.all.size
    end
  end

  describe ".rack_app" do
    it "raises ConfigurationError when no authenticator is configured" do
      assert_raises(Riffer::McpServer::ConfigurationError) do
        Riffer::McpServer.rack_app
      end
    end

    it "is memoized — repeated calls return the same instance" do
      Riffer::McpServer.configure { |s| s.authenticator = ->(_t) { Object.new } }
      first = Riffer::McpServer.rack_app
      second = Riffer::McpServer.rack_app
      assert_same first, second
    end
  end

  describe ".reset!" do
    it "clears the registry" do
      Riffer::McpServer.configure do |s|
        s.expose Test::PingTool
        s.authenticator = ->(_t) { Object.new }
      end
      Riffer::McpServer.reset!
      assert_empty Riffer::McpServer.registry.all
    end

    it "drops the configured authenticator" do
      Riffer::McpServer.configure { |s| s.authenticator = ->(_t) { Object.new } }
      Riffer::McpServer.reset!
      assert_nil Riffer::McpServer.config.authenticator
    end

    it "drops the cached rack_app so subsequent .rack_app builds afresh" do
      Riffer::McpServer.configure { |s| s.authenticator = ->(_t) { Object.new } }
      first = Riffer::McpServer.rack_app
      Riffer::McpServer.reset!
      Riffer::McpServer.configure { |s| s.authenticator = ->(_t) { Object.new } }
      refute_same first, Riffer::McpServer.rack_app
    end
  end
end
