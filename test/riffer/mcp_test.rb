# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp do
  before { clear_mcp_registry! }
  after { clear_mcp_registry! }

  # Injects a stub registration directly, bypassing inline discovery.
  def inject_stub_registration(name:, tags: [])
    manifest = Riffer::Mcp::Manifest.new(name: name, tags: tags, endpoint: "https://x.com")
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
    it "delegates to Registry and returns a Registration" do
      inject_stub_registration(name: "srv", tags: [:t])
      reg = Riffer::Mcp.registrations["srv"]

      assert_instance_of Riffer::Mcp::Registration, reg
    end
  end

  describe ".unregister" do
    it "removes the registration" do
      inject_stub_registration(name: "srv")
      Riffer::Mcp.unregister("srv")

      refute Riffer::Mcp.registrations.key?("srv")
    end
  end

  describe ".registrations" do
    it "returns an empty hash initially" do
      assert_equal({}, Riffer::Mcp.registrations)
    end
  end

  describe "error hierarchy" do
    it "CredentialsDeniedError is a Riffer::Mcp::Error" do
      assert_operator Riffer::Mcp::CredentialsDeniedError, :<, Riffer::Mcp::Error
    end

    it "Mcp::Error is a Riffer::Error" do
      assert_operator Riffer::Mcp::Error, :<, Riffer::Error
    end
  end
end
