# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Messages::System do
  describe "#role" do
    it "returns system" do
      message = described_class.new("You are helpful")
      expect(message.role).to eq("system")
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = described_class.new("You are helpful")
      expect(message.to_h).to eq({role: "system", content: "You are helpful"})
    end
  end
end
