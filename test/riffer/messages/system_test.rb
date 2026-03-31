# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::System do
  describe "#role" do
    it "returns system" do
      message = Riffer::Messages::System.new("You are helpful")
      expect(message.role).must_equal :system
    end
  end

  describe "#timestamp" do
    it "sets a default timestamp" do
      before = Time.now
      message = Riffer::Messages::System.new("You are helpful")
      after = Time.now
      expect(message.timestamp).must_be :>=, before
      expect(message.timestamp).must_be :<=, after
    end

    it "accepts a custom timestamp" do
      custom_time = Time.new(2025, 1, 15, 12, 0, 0)
      message = Riffer::Messages::System.new("You are helpful", timestamp: custom_time)
      expect(message.timestamp).must_equal custom_time
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::System.new("You are helpful")
      expect(message.to_h.except(:timestamp)).must_equal({role: :system, content: "You are helpful"})
    end

    it "includes timestamp as ISO 8601 with milliseconds" do
      custom_time = Time.new(2025, 1, 15, 12, 0, 0)
      message = Riffer::Messages::System.new("You are helpful", timestamp: custom_time)
      expect(message.to_h[:timestamp]).must_equal custom_time.iso8601(3)
    end
  end
end
