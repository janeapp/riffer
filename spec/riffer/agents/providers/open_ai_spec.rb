# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::OpenAI do
  describe "#generate_text" do
    it "returns a response hash" do
      result = described_class.new.generate_text(messages: [])
      expect(result).to be_a(Hash)
    end
  end

  describe "#stream_text" do
    it "returns an enumerator" do
      result = described_class.new.stream_text(messages: [])
      expect(result).to be_a(Enumerator)
    end
  end
end
