# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Storage::SqliteAdapter do
  let(:adapter) { described_class.new }

  describe "#save and #load" do
    it "saves and loads values" do
      adapter.save("test_key", "test_value")
      expect(adapter.load("test_key")).to eq("test_value")
    end

    it "returns nil for non-existent keys" do
      expect(adapter.load("non_existent")).to be_nil
    end
  end

  describe "#delete" do
    it "deletes a key" do
      adapter.save("test_key", "test_value")
      adapter.delete("test_key")
      expect(adapter.load("test_key")).to be_nil
    end
  end
end
