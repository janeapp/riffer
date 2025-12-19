# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Core do
  describe "#initialize" do
    it "creates a logger instance" do
      core = described_class.new
      expect(core.logger).to be_a(Logger)
    end
  end

  describe "#configure" do
    it "yields self for configuration" do
      core = described_class.new
      expect { |b| core.configure(&b) }.to yield_with_args(core)
    end
  end
end
