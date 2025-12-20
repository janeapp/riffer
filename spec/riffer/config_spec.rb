# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Config do
  describe "#initialize" do
    it "initializes with nil openai_api_key" do
      config = described_class.new
      expect(config.openai_api_key).to be_nil
    end
  end

  describe "#openai_api_key=" do
    it "sets the openai_api_key" do
      config = described_class.new
      config.openai_api_key = "test-key"
      expect(config.openai_api_key).to eq("test-key")
    end
  end

  describe "module methods" do
    describe ".config" do
      it "returns a Config instance" do
        expect(Riffer.config).to be_a(described_class)
      end
    end

    describe ".configure" do
      it "yields the config object" do
        expect { |b| Riffer.configure(&b) }.to yield_with_args(described_class)
      end

      # rubocop:disable RSpec/ExampleLength
      it "allows setting configuration" do
        original_key = Riffer.config.openai_api_key
        Riffer.configure do |config|
          config.openai_api_key = "new-test-key"
        end
        expect(Riffer.config.openai_api_key).to eq("new-test-key")
        Riffer.config.openai_api_key = original_key
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end
end
