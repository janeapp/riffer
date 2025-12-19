# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::Base do
  let(:provider) { described_class.new }

  describe "#generate_text" do
    it "raises NotImplementedError" do
      expect {
        provider.generate_text(messages: [])
      }.to raise_error(NotImplementedError, "Subclasses must implement #generate_text")
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError" do
      expect {
        provider.stream_text(messages: [])
      }.to raise_error(NotImplementedError, "Subclasses must implement #stream_text")
    end
  end
end
