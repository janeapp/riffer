# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::User do
  describe "#role" do
    it "returns user" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.role).must_equal :user
    end
  end

  describe "#to_h" do
    it "returns hash with role and content" do
      message = Riffer::Messages::User.new("Hello")
      expect(message.to_h).must_equal({role: :user, content: "Hello"})
    end
  end
end
