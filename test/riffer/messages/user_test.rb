# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::User do
  describe "#role" do
    it "returns user" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.role).must_equal "user"
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.to_h).must_equal({role: "user", content: "Hello"})
    end
  end

  describe "#initialize" do
    describe "validation" do
      it "raises InvalidInputError when content is nil" do
        error = expect {
          Riffer::Messages::User.new(nil)
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_equal "User message content cannot be nil"
      end

      it "raises InvalidInputError when content is empty string" do
        error = expect {
          Riffer::Messages::User.new("")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_equal "User message content cannot be empty"
      end

      it "raises InvalidInputError when content is whitespace only" do
        error = expect {
          Riffer::Messages::User.new("   ")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_equal "User message content cannot be empty"
      end

      it "accepts valid content" do
        message = Riffer::Messages::User.new("Valid content")
        expect(message.content).must_equal "Valid content"
      end
    end
  end
end
