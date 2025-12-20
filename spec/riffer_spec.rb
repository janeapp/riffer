# frozen_string_literal: true

RSpec.describe Riffer do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  describe ".config" do
    it "returns a Config instance" do
      expect(described_class.config).to be_a(described_class::Config)
    end

    it "returns the same instance on multiple calls" do
      config1 = described_class.config
      config2 = described_class.config
      expect(config1.object_id).to eq(config2.object_id)
    end
  end

  describe ".configure" do
    let(:original_api_key) { described_class.config.openai.api_key }

    after do
      described_class.config.openai.api_key = original_api_key
    end

    it "yields the config object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class::Config)
    end

    it "allows setting configuration" do
      described_class.configure do |config|
        config.openai.api_key = "new-test-key"
      end
      expect(described_class.config.openai.api_key).to eq("new-test-key")
    end
  end
end
