# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Core do
  describe "#initialize" do
    it "creates a core instance with logger and storage registry" do
      core = described_class.new
      expect(core.logger).to be_a(Logger)
      expect(core.storage_registry).to eq({})
    end
  end

  describe "#register_storage" do
    it "registers a storage adapter" do
      core = described_class.new
      adapter = double("adapter")
      core.register_storage(:test, adapter)
      expect(core.get_storage(:test)).to eq(adapter)
    end
  end

  describe "#configure" do
    it "yields self for configuration" do
      core = described_class.new
      expect { |b| core.configure(&b) }.to yield_with_args(core)
    end
  end
end
