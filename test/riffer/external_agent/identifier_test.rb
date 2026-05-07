# frozen_string_literal: true

require "test_helper"

describe Riffer::ExternalAgent::Identifier do
  describe "#initialize" do
    it "stores vendor, raw, and resolved" do
      id = Riffer::ExternalAgent::Identifier.new(vendor: "claude-code", raw: "2.1.0", resolved: "2.1.0")
      expect(id.vendor).must_equal "claude-code"
      expect(id.raw).must_equal "2.1.0"
      expect(id.resolved).must_equal "2.1.0"
    end

    it "allows resolved to differ from raw" do
      id = Riffer::ExternalAgent::Identifier.new(vendor: "claude-code", raw: "latest", resolved: "2.1.131")
      expect(id.raw).must_equal "latest"
      expect(id.resolved).must_equal "2.1.131"
    end

    it "is frozen" do
      id = Riffer::ExternalAgent::Identifier.new(vendor: "v", raw: "r", resolved: "r")
      expect(id.frozen?).must_equal true
    end

    it "freezes the string attributes" do
      id = Riffer::ExternalAgent::Identifier.new(vendor: "v", raw: "r", resolved: "r")
      expect(id.vendor.frozen?).must_equal true
      expect(id.raw.frozen?).must_equal true
      expect(id.resolved.frozen?).must_equal true
    end
  end
end
