# frozen_string_literal: true

require "test_helper"

describe Riffer::McpServer::Config do
  let(:registry) { Riffer::McpServer::Registry.new }
  let(:config) { Riffer::McpServer::Config.new(registry: registry) }

  let(:tool_class) do
    Class.new(Riffer::Tool) do
      identifier "demo"
      description "Demo"
    end
  end

  describe "defaults" do
    it "has no authenticator" do
      assert_nil config.authenticator
    end

    it "has a context_builder that returns an empty hash" do
      assert_equal({}, config.context_builder.call(Object.new))
    end

    it "has a default server_name" do
      refute_nil config.server_name
      refute_empty config.server_name
    end

    it "has a default server_version" do
      refute_nil config.server_version
    end
  end

  describe "#expose" do
    it "delegates to the registry" do
      config.expose(tool_class)
      assert_equal tool_class, registry.lookup("demo")[:tool_class]
    end

    it "passes the scope through to the registry" do
      config.expose(tool_class, scope: :admin)
      assert_equal :admin, registry.lookup("demo")[:scope]
    end
  end

  describe "writers" do
    it "stores an authenticator" do
      proc_value = ->(t) { t }
      config.authenticator = proc_value
      assert_equal proc_value, config.authenticator
    end

    it "stores a context_builder" do
      proc_value = ->(t) { {role: t} }
      config.context_builder = proc_value
      assert_equal proc_value, config.context_builder
    end

    it "stores a custom server_name" do
      config.server_name = "custom"
      assert_equal "custom", config.server_name
    end

    it "stores a custom server_version" do
      config.server_version = "9.9.9"
      assert_equal "9.9.9", config.server_version
    end
  end
end
