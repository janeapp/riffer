# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp do
  before { clear_mcp_registry! }
  after { clear_mcp_registry! }

  describe ".register" do
    it "returns a Registration" do
      reg = Riffer::Mcp.register(name: "srv", tags: [:t], endpoint: "https://x.com")
      assert_instance_of Riffer::Mcp::Registration, reg
    end

    it "adds to registrations" do
      Riffer::Mcp.register(name: "srv", tags: [], endpoint: "https://x.com")
      assert Riffer::Mcp.registrations.key?("srv")
    end
  end

  describe ".unregister" do
    it "removes the registration" do
      Riffer::Mcp.register(name: "srv", tags: [], endpoint: "https://x.com")
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
    it "NotReadyError is a Riffer::Mcp::Error" do
      assert Riffer::Mcp::NotReadyError < Riffer::Mcp::Error
    end

    it "TimeoutError is a Riffer::Mcp::Error" do
      assert Riffer::Mcp::TimeoutError < Riffer::Mcp::Error
    end

    it "CredentialsDeniedError is a Riffer::Mcp::Error" do
      assert Riffer::Mcp::CredentialsDeniedError < Riffer::Mcp::Error
    end

    it "Mcp::Error is a Riffer::Error" do
      assert Riffer::Mcp::Error < Riffer::Error
    end
  end
end
