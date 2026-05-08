# frozen_string_literal: true

require "test_helper"

describe Riffer::McpServer::AuthMiddleware do
  let(:token_env_key) { "riffer.mcp_server.token" }

  let(:registry) { Riffer::McpServer::Registry.new }
  let(:config) { Riffer::McpServer::Config.new(registry: registry) }
  let(:passthrough) { ->(env) { [200, {}, ["ok #{env[token_env_key].inspect}"]] } }
  let(:middleware) { Riffer::McpServer::AuthMiddleware.new(passthrough, config: config) }

  def build_env(authorization: nil)
    env = {
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/",
      "HTTP_HOST" => "example.com",
      "rack.input" => StringIO.new("")
    }
    env["HTTP_AUTHORIZATION"] = authorization if authorization
    env
  end

  describe "rejection paths" do
    before { config.authenticator = ->(_t) { Object.new } }

    it "returns 401 when the Authorization header is missing" do
      status, _, body = middleware.call(build_env)
      assert_equal 401, status
      body_str = body.respond_to?(:join) ? body.join : body.first
      assert_match(/missing authorization/i, body_str)
    end

    it "returns 401 when the scheme is not Bearer" do
      status, _, _ = middleware.call(build_env(authorization: "Basic abc"))
      assert_equal 401, status
    end

    it "returns 401 when the Bearer token is empty" do
      status, _, _ = middleware.call(build_env(authorization: "Bearer "))
      assert_equal 401, status
    end

    it "returns 401 when the authenticator returns nil" do
      config.authenticator = ->(_t) {}
      status, _, _ = middleware.call(build_env(authorization: "Bearer xyz"))
      assert_equal 401, status
    end

    it "returns 401 when the authenticator raises" do
      config.authenticator = ->(_t) { raise "boom" }
      status, _, _ = middleware.call(build_env(authorization: "Bearer xyz"))
      assert_equal 401, status
    end

    it "returns a JSON-RPC-shaped error body" do
      _, headers, body = middleware.call(build_env)
      assert_equal "application/json", headers["Content-Type"]
      parsed = JSON.parse(body.first)
      assert_equal "2.0", parsed["jsonrpc"]
      assert parsed["error"].is_a?(Hash)
      refute_nil parsed["error"]["code"]
      refute_nil parsed["error"]["message"]
    end
  end

  describe "success path" do
    it "calls the inner app and stashes the token object in env" do
      token_object = Struct.new(:role).new(:admin)
      config.authenticator = ->(t) { (t == "good") ? token_object : nil }

      status, _, body = middleware.call(build_env(authorization: "Bearer good"))
      assert_equal 200, status
      assert_match(/role=:admin/, body.first)
    end

    it "raises ConfigurationError if no authenticator is configured" do
      config.authenticator = nil
      assert_raises(Riffer::McpServer::ConfigurationError) do
        middleware.call(build_env(authorization: "Bearer x"))
      end
    end
  end
end
