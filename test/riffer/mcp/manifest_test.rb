# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::Manifest do
  describe ".new" do
    it "stores name, endpoint, and discovery_headers" do
      manifest = Riffer::Mcp::Manifest.new(name: "github", tags: [:github], endpoint: "https://example.com",
                                           discovery_headers: {},)

      assert_equal "github", manifest.name
      assert_equal "https://example.com", manifest.endpoint
      assert_equal({}, manifest.discovery_headers)
    end

    it "normalizes name to a string" do
      manifest = Riffer::Mcp::Manifest.new(name: :github, tags: [], endpoint: "https://x.com")

      assert_equal "github", manifest.name
    end

    it "normalizes tags to symbols" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: ["foo", :bar], endpoint: "https://x.com")

      assert_equal %i[foo bar], manifest.tags
    end

    it "wraps a single tag in an array" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: :solo, endpoint: "https://x.com")

      assert_equal [:solo], manifest.tags
    end

    it "defaults tags to empty array when nil" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: nil, endpoint: "https://x.com")

      assert_equal [], manifest.tags
    end

    it "accepts a Proc for discovery_headers" do
      proc_headers = -> { { "Authorization" => "Bearer token" } }
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: [], endpoint: "https://x.com",
                                           discovery_headers: proc_headers,)

      assert_equal proc_headers, manifest.discovery_headers
    end

    it "normalizes credentials_scope to a symbol" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: [], endpoint: "https://x.com", credentials_scope: "user")

      assert_equal :user, manifest.credentials_scope
    end

    it "allows nil credentials_scope" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: [], endpoint: "https://x.com")

      assert_nil manifest.credentials_scope
    end

    it "strips whitespace from name" do
      manifest = Riffer::Mcp::Manifest.new(name: "  srv  ", tags: [], endpoint: "https://x.com")

      assert_equal "srv", manifest.name
    end

    it "raises when name is blank" do
      err = assert_raises(Riffer::ArgumentError) { Riffer::Mcp::Manifest.new(name: "  ", tags: [], endpoint: "https://x.com") }
      assert_match(/name is required/, err.message)
    end

    it "strips whitespace from endpoint" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: [], endpoint: "  https://x.com  ")

      assert_equal "https://x.com", manifest.endpoint
    end

    it "raises when endpoint is not an https URL" do
      err = assert_raises(Riffer::ArgumentError) { Riffer::Mcp::Manifest.new(name: "srv", tags: [], endpoint: "not-a-url") }
      assert_match(/valid HTTPS URL/, err.message)
    end

    it "raises when endpoint is http rather than https" do
      err = assert_raises(Riffer::ArgumentError) { Riffer::Mcp::Manifest.new(name: "srv", tags: [], endpoint: "http://localhost:3000") }
      assert_match(/valid HTTPS URL/, err.message)
    end
  end
end
