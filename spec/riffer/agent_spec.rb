# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agent do
  describe ".new" do
    it "can be instantiated" do
      agent = described_class.new
      expect(agent).to be_a(Riffer::Agent)
    end

    it "accepts options" do
      agent = described_class.new(model: "gpt-4")
      expect(agent).to be_a(Riffer::Agent)
    end
  end
end
