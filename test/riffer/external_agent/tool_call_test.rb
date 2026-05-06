# frozen_string_literal: true

require "test_helper"

describe Riffer::ExternalAgent::ToolCall do
  describe "#initialize" do
    it "stores the name" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {q: "ruby"})
      expect(call.name).must_equal "search"
    end

    it "stores the arguments" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {q: "ruby"})
      expect(call.arguments).must_equal({q: "ruby"})
    end

    it "defaults result to nil" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {})
      expect(call.result).must_be_nil
    end

    it "stores the result" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {}, result: "match")
      expect(call.result).must_equal "match"
    end

    it "defaults error to nil" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {})
      expect(call.error).must_be_nil
    end

    it "stores the error" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {}, error: "boom")
      expect(call.error).must_equal "boom"
    end
  end

  describe "#error?" do
    it "returns false when no error is set" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {})
      expect(call.error?).must_equal false
    end

    it "returns true when an error is set" do
      call = Riffer::ExternalAgent::ToolCall.new(name: "search", arguments: {}, error: "boom")
      expect(call.error?).must_equal true
    end
  end
end
