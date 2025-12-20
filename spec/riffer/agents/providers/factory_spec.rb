# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Factory do
  describe ".build" do
    context "with test provider" do
      it "builds a test provider" do
        provider = described_class.build("test/model")
        expect(provider).to be_a(Riffer::Agents::Providers::Test)
      end
    end

    context "with openai provider" do
      let(:original_api_key) { Riffer.config.openai.api_key }

      after do
        Riffer.config.openai.api_key = original_api_key
      end

      it "builds an OpenAI provider with config API key" do
        Riffer.config.openai.api_key = "config-test-key"
        provider = described_class.build("openai/gpt-4")

        expect(provider).to be_a(Riffer::Agents::Providers::OpenAI)
      end

      it "builds an OpenAI provider with explicit API key" do
        provider = described_class.build("openai/gpt-4", api_key: "explicit-test-key")
        expect(provider).to be_a(Riffer::Agents::Providers::OpenAI)
      end
    end

    context "with invalid model string" do
      it "raises error for missing provider/model separator" do
        expect {
          described_class.build("invalid-model")
        }.to raise_error(ArgumentError, /Model string must be in format/)
      end
    end

    context "with unknown provider" do
      it "raises error" do
        expect {
          described_class.build("unknown/model")
        }.to raise_error(ArgumentError, /Unknown provider: unknown/)
      end
    end
  end
end
