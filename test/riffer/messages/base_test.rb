# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Base do
  let(:base_message) { Riffer::Messages::Base.new("Test content") }

  describe "#initialize" do
    it "sets the content" do
      expect(base_message.content).must_equal "Test content"
    end

    it "sets a default timestamp" do
      before = Time.now
      message = Riffer::Messages::Base.new("Test")
      after = Time.now
      expect(message.timestamp).must_be :>=, before
      expect(message.timestamp).must_be :<=, after
    end

    it "accepts a custom timestamp" do
      custom_time = Time.new(2025, 1, 15, 12, 0, 0)
      message = Riffer::Messages::Base.new("Test", timestamp: custom_time)
      expect(message.timestamp).must_equal custom_time
    end
  end

  describe "#role" do
    it "raises NotImplementedError" do
      error = expect { base_message.role }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #role"
    end
  end

  describe "#to_h" do
    it "raises NotImplementedError when role is not implemented" do
      expect { base_message.to_h }.must_raise(NotImplementedError)
    end
  end
end
