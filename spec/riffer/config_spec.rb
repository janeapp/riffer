# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Config do
  describe "#initialize" do
    it "initializes openai namespace" do
      config = described_class.new
      expect(config.openai).to be_a(Riffer::Config::OpenAIConfig)
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

  describe "module methods" do
    let(:original_api_key) { Riffer.config.openai.api_key }

    after do
      Riffer.config.openai.api_key = original_api_key
    end

    describe ".config" do
      it "returns a Config instance" do
        expect(Riffer.config).to be_a(described_class)
      end
    end

    describe ".configure" do
      it "yields the config object" do
        expect { |b| Riffer.configure(&b) }.to yield_with_args(described_class)
      end

      it "allows setting configuration" do
        Riffer.configure do |config|
          config.openai.api_key = "new-test-key"
        end
        expect(Riffer.config.openai.api_key).to eq("new-test-key")
      end
    end
  end
end
