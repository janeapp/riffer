# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::StreamEvents::Base do
  describe "#initialize" do
    it "sets default role to assistant" do
      event = described_class.new
      expect(event.role).to eq("assistant")
    end

    it "allows setting custom role" do
      event = described_class.new(role: "user")
      expect(event.role).to eq("user")
    end
  end

  describe "#to_h" do
    it "raises NotImplementedError" do
      event = described_class.new
      expect { event.to_h }.to raise_error(NotImplementedError)
    end
  end
end
