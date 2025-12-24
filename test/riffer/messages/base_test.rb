# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Base do
  let(:base_message) { Riffer::Messages::Base.new("Test content") }

  describe "#initialize" do
    it "sets the content" do
      expect(base_message.content).must_equal "Test content"
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
