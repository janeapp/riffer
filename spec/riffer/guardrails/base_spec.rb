# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Guardrails::Base do
  describe "#process_input" do
    it "returns content unchanged by default" do
      guardrail = described_class.new
      expect(guardrail.process_input("test content")).to eq("test content")
    end
  end

  describe "#process_output" do
    it "returns content unchanged by default" do
      guardrail = described_class.new
      expect(guardrail.process_output("test content")).to eq("test content")
    end
  end
end
