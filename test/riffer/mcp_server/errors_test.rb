# frozen_string_literal: true

require "test_helper"

describe "Riffer::McpServer error hierarchy" do
  it "Riffer::McpServer::Error inherits from Riffer::Error" do
    assert_operator Riffer::McpServer::Error, :<, Riffer::Error
  end

  it "Riffer::McpServer::AuthenticationError inherits from Riffer::McpServer::Error" do
    assert_operator Riffer::McpServer::AuthenticationError, :<, Riffer::McpServer::Error
  end

  it "Riffer::McpServer::ConfigurationError inherits from Riffer::McpServer::Error" do
    assert_operator Riffer::McpServer::ConfigurationError, :<, Riffer::McpServer::Error
  end

  it "all errors are StandardError descendants" do
    [Riffer::McpServer::Error, Riffer::McpServer::AuthenticationError, Riffer::McpServer::ConfigurationError].each do |klass|
      assert_operator klass, :<, StandardError
    end
  end
end
