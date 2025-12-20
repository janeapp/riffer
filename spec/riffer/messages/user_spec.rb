# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Messages::User do
  describe "#role" do
    it "returns user" do
      message = described_class.new("Hello")
      expect(message.role).to eq("user")
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = described_class.new("Hello")
      expect(message.to_h).to eq({role: "user", content: "Hello"})
    end
  end
end
