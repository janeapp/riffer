# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::System do
  describe "#role" do
    it "returns system" do
      message = Riffer::Messages::System.new("You are helpful")

      expect(message.role).must_equal :system
    end
  end

  describe "#+" do
    it "concatenates content" do
      a = Riffer::Messages::System.new("Rule one")
      b = Riffer::Messages::System.new("Rule two")

      result = a + b

      expect(result.content).must_equal "Rule one\n\nRule two"
    end

    it "returns a System message" do
      a = Riffer::Messages::System.new("Rule one")
      b = Riffer::Messages::System.new("Rule two")

      result = a + b

      expect(result).must_be_instance_of Riffer::Messages::System
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::System.new("You are helpful")

      expect(message.to_h).must_equal({ role: :system, content: "You are helpful" })
    end
  end
end
