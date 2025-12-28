# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::System do
  describe "#role" do
    it "returns system" do
      message = Riffer::Messages::System.new("You are helpful")
      expect(message.role).must_equal "system"
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::System.new("You are helpful")
      expect(message.to_h).must_equal({role: "system", content: "You are helpful"})
    end
  end

  describe "#initialize" do
    describe "validation" do
      it "raises InvalidInputError when content is nil" do
        error = expect {
          Riffer::Messages::System.new(nil)
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_equal "System message content cannot be nil"
      end

      it "raises InvalidInputError when content is empty string" do
        error = expect {
          Riffer::Messages::System.new("")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_equal "System message content cannot be empty"
      end

      it "raises InvalidInputError when content is whitespace only" do
        error = expect {
          Riffer::Messages::System.new("   ")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_equal "System message content cannot be empty"
      end

      it "accepts valid content" do
        message = Riffer::Messages::System.new("Be helpful")
        expect(message.content).must_equal "Be helpful"
      end
    end
  end
end
