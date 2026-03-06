# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::Registry do
  before { clear_mcp_registry! }
  after { clear_mcp_registry! }

  describe ".register" do
    it "accepts a Manifest instance" do
      manifest = Riffer::Mcp::Manifest.new(name: "srv", tags: [:foo], endpoint: "https://x.com")
      reg = Riffer::Mcp::Registry.register(manifest)
      assert_instance_of Riffer::Mcp::Registration, reg
    end

    it "accepts a hash" do
      reg = Riffer::Mcp::Registry.register(name: "srv", tags: [:foo], endpoint: "https://x.com")
      assert_instance_of Riffer::Mcp::Registration, reg
    end

    it "stores the registration by name" do
      Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://x.com")
      assert Riffer::Mcp::Registry.registrations.key?("srv")
    end

    it "replaces an existing registration with the same name" do
      Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://a.com")
      reg2 = Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://b.com")
      assert_equal reg2, Riffer::Mcp::Registry.registrations["srv"]
      assert_equal "https://b.com", Riffer::Mcp::Registry.registrations["srv"].manifest.endpoint
    end

    it "retires the previous registration when replacing" do
      old_reg = Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://a.com")
      Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://b.com")
      assert old_reg.retired?
    end
  end

  describe ".unregister" do
    it "removes a registration by name" do
      Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://x.com")
      Riffer::Mcp::Registry.unregister("srv")
      refute Riffer::Mcp::Registry.registrations.key?("srv")
    end

    it "removes a registration registered with a symbol name" do
      Riffer::Mcp::Registry.register(name: :github, tags: [], endpoint: "https://x.com")
      Riffer::Mcp::Registry.unregister("github")
      refute Riffer::Mcp::Registry.registrations.key?("github")
    end

    it "does not raise when name is not registered" do
      assert_nil Riffer::Mcp::Registry.unregister("nonexistent")
    end

    it "retires the registration when unregistered" do
      reg = Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://x.com")
      Riffer::Mcp::Registry.unregister("srv")
      assert reg.retired?
    end
  end

  describe ".registrations" do
    it "returns an empty hash when nothing is registered" do
      assert_equal({}, Riffer::Mcp::Registry.registrations)
    end

    it "returns a frozen snapshot" do
      Riffer::Mcp::Registry.register(name: "srv", tags: [], endpoint: "https://x.com")
      snapshot = Riffer::Mcp::Registry.registrations
      assert snapshot.frozen?
    end
  end

  describe ".find_by_tags" do
    it "returns registrations whose tags intersect the query" do
      Riffer::Mcp::Registry.register(name: "a", tags: [:foo, :bar], endpoint: "https://a.com")
      Riffer::Mcp::Registry.register(name: "b", tags: [:baz], endpoint: "https://b.com")
      results = Riffer::Mcp::Registry.find_by_tags([:foo])
      assert_equal 1, results.size
      assert_equal "a", results.first.manifest.name
    end

    it "returns empty array when no tags match" do
      Riffer::Mcp::Registry.register(name: "a", tags: [:foo], endpoint: "https://a.com")
      assert_empty Riffer::Mcp::Registry.find_by_tags([:zzz])
    end

    it "normalizes string tags to symbols for matching" do
      Riffer::Mcp::Registry.register(name: "a", tags: [:foo], endpoint: "https://a.com")
      results = Riffer::Mcp::Registry.find_by_tags(["foo"])
      assert_equal 1, results.size
    end

    it "returns multiple matches when several registrations share a tag" do
      Riffer::Mcp::Registry.register(name: "a", tags: [:shared], endpoint: "https://a.com")
      Riffer::Mcp::Registry.register(name: "b", tags: [:shared], endpoint: "https://b.com")
      assert_equal 2, Riffer::Mcp::Registry.find_by_tags([:shared]).size
    end
  end
end
