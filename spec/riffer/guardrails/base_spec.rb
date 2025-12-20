# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Guardrails::Base do
  describe "#initialize" do
    it "accepts action parameter" do
      guardrail = described_class.new(action: :redact)
      expect(guardrail.action).to eq(:redact)
    end

    it "defaults to :mutate action" do
      guardrail = described_class.new
      expect(guardrail.action).to eq(:mutate)
    end
  end

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
