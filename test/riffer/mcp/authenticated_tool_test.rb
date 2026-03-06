# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::AuthenticatedTool do
  let(:inner) do
    Class.new(Riffer::Tool) do
      define_singleton_method(:name) { "echo" }
      define_singleton_method(:description) { "E" }
      define_singleton_method(:parameters_schema) { |strict: false| Riffer::Tool.send(:empty_schema) }

      define_method(:call) do |context:, **kwargs|
        text("inner-#{kwargs[:x]}")
      end
    end
  end

  let(:manifest) do
    Riffer::Mcp::Manifest.new(name: "srv", tags: [:t], endpoint: "https://mcp.example.com", discovery_headers: {})
  end

  it "delegates to inner when credentials proc is nil" do
    prev = Riffer.config.mcp.credentials
    Riffer.config.mcp.credentials = nil
    wrapped = Riffer::Mcp::AuthenticatedTool.wrap_one(inner, manifest, [:t])
    resp = wrapped.new.call(context: {}, x: 1)
    assert_equal "inner-1", resp.content
  ensure
    Riffer.config.mcp.credentials = prev
  end

  it "raises CredentialsDeniedError when credentials returns nil during call" do
    prev = Riffer.config.mcp.credentials
    Riffer.config.mcp.credentials = lambda do |manifest:, matched_tags:, context:|
    end
    wrapped = Riffer::Mcp::AuthenticatedTool.wrap_one(inner, manifest, [:t])
    assert_raises(Riffer::Mcp::CredentialsDeniedError) { wrapped.new.call(context: {}, x: 1) }
  ensure
    Riffer.config.mcp.credentials = prev
  end
end
