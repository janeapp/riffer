# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Messages::Base do
  let(:message) { described_class.new("Test content") }

  describe "#initialize" do
    it "sets the content" do
      expect(message.content).to eq("Test content")
    end
  end

  describe "#role" do
    it "raises NotImplementedError" do
      expect {
        message.role
      }.to raise_error(NotImplementedError, "Subclasses must implement #role")
    end
  end

  describe "#to_h" do
    it "raises NotImplementedError when role is not implemented" do
      expect {
        message.to_h
      }.to raise_error(NotImplementedError, "Subclasses must implement #role")
    end
  end
end
