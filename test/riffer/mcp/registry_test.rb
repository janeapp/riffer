# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::Registry do
  before { clear_mcp_registry! }
  after { clear_mcp_registry! }

  # Injects a stub registration directly into the registry store, bypassing discovery.
  def inject_stub_registration(name:, tags:, endpoint: "https://x.com")
    manifest = Riffer::Mcp::Manifest.new(name: name, tags: tags, endpoint: endpoint)
    reg = Riffer::Mcp::Registration.allocate
    reg.instance_variable_set(:@manifest, manifest)
    reg.instance_variable_set(:@cancelled, false)
    reg.instance_variable_set(:@tools, [])
    reg.instance_variable_set(:@mutex, Mutex.new)
    store = Riffer::Mcp::Registry.instance_variable_get(:@store)
    Riffer::Mcp::Registry.instance_variable_get(:@mutex).synchronize { store[name] = reg }
    reg
  end

  describe ".register" do
    it "stores the registration by name" do
      inject_stub_registration(name: "srv", tags: [])
      assert Riffer::Mcp::Registry.registrations.key?("srv")
    end

    it "replaces an existing registration with the same name" do
      inject_stub_registration(name: "srv", tags: [], endpoint: "https://a.com")
      reg2 = inject_stub_registration(name: "srv", tags: [], endpoint: "https://b.com")
      assert_equal reg2, Riffer::Mcp::Registry.registrations["srv"]
      assert_equal "https://b.com", Riffer::Mcp::Registry.registrations["srv"].manifest.endpoint
    end

    it "retires the previous registration when replacing" do
      old_reg = inject_stub_registration(name: "srv", tags: [], endpoint: "https://a.com")
      new_reg = inject_stub_registration(name: "srv", tags: [], endpoint: "https://b.com")
      old_reg.retire!
      assert old_reg.retired?
      refute new_reg.retired?
    end
  end

  describe ".unregister" do
    it "removes a registration by name" do
      inject_stub_registration(name: "srv", tags: [])
      Riffer::Mcp::Registry.unregister("srv")
      refute Riffer::Mcp::Registry.registrations.key?("srv")
    end

    it "removes a registration registered with a symbol name" do
      inject_stub_registration(name: "github", tags: [])
      Riffer::Mcp::Registry.unregister("github")
      refute Riffer::Mcp::Registry.registrations.key?("github")
    end

    it "does not raise when name is not registered" do
      assert_nil Riffer::Mcp::Registry.unregister("nonexistent")
    end

    it "retires the registration when unregistered" do
      reg = inject_stub_registration(name: "srv", tags: [])
      Riffer::Mcp::Registry.unregister("srv")
      assert reg.retired?
    end
  end

  describe ".registrations" do
    it "returns an empty hash when nothing is registered" do
      assert_equal({}, Riffer::Mcp::Registry.registrations)
    end

    it "returns a frozen snapshot" do
      inject_stub_registration(name: "srv", tags: [])
      snapshot = Riffer::Mcp::Registry.registrations
      assert snapshot.frozen?
    end
  end

  describe ".find_by_tags" do
    it "returns registrations whose tags intersect the query" do
      inject_stub_registration(name: "a", tags: [:foo, :bar])
      inject_stub_registration(name: "b", tags: [:baz])
      results = Riffer::Mcp::Registry.find_by_tags([:foo])
      assert_equal 1, results.size
      assert_equal "a", results.first.manifest.name
    end

    it "returns empty array when no tags match" do
      inject_stub_registration(name: "a", tags: [:foo])
      assert_empty Riffer::Mcp::Registry.find_by_tags([:zzz])
    end

    it "normalizes string tags to symbols for matching" do
      inject_stub_registration(name: "a", tags: [:foo])
      results = Riffer::Mcp::Registry.find_by_tags(["foo"])
      assert_equal 1, results.size
    end

    it "returns multiple matches when several registrations share a tag" do
      inject_stub_registration(name: "a", tags: [:shared])
      inject_stub_registration(name: "b", tags: [:shared])
      assert_equal 2, Riffer::Mcp::Registry.find_by_tags([:shared]).size
    end
  end
end
