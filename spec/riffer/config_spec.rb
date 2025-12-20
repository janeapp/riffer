# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Config do
  describe "#initialize" do
    it "initializes openai namespace" do
      config = described_class.new
      expect(config.openai).to be_a(Struct)
    end

    it "initializes with nil openai api_key" do
      config = described_class.new
      expect(config.openai.api_key).to be_nil
    end
  end

  describe "openai namespace" do
    it "allows setting the api_key" do
      config = described_class.new
      config.openai.api_key = "test-key"
      expect(config.openai.api_key).to eq("test-key")
    end
  end
end
