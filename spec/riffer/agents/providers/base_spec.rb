# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Base do
  describe "#initialize" do
    it "accepts an api_key parameter" do
      provider = described_class.new(api_key: "test_key")
      expect(provider.instance_variable_get(:@api_key)).to eq("test_key")
    end

    it "accepts additional options" do
      provider = described_class.new(custom_option: "value")
      expect(provider.instance_variable_get(:@options)).to eq({custom_option: "value"})
    end
  end

  describe "#chat" do
    it "raises NotImplementedError" do
      provider = described_class.new
      expect {
        provider.chat(messages: [], model: "test")
      }.to raise_error(NotImplementedError, "Subclasses must implement #chat")
    end
  end
end
