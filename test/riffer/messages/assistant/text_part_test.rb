# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Assistant::TextPart do
  describe "#initialize" do
    it "stores the text, the provider block and its format" do
      part = Riffer::Messages::Assistant::TextPart.new("4.0.9", data: '{"type":"text"}', format: "mock-v1")

      expect([part.text, part.data, part.format]).must_equal ["4.0.9", '{"type":"text"}', "mock-v1"]
    end

    it "defaults the block and format to nil" do
      part = Riffer::Messages::Assistant::TextPart.new("Hi")

      expect([part.data, part.format]).must_equal [nil, nil]
    end
  end

  describe "#to_h" do
    it "omits the fields it doesn't carry" do
      expect(Riffer::Messages::Assistant::TextPart.new("Hi").to_h).must_equal({ text: "Hi" })
    end
  end

  describe ".from_hash" do
    it "round-trips every field" do
      part = Riffer::Messages::Assistant::TextPart.new("Hi", data: "{}", format: "mock-v1")

      expect(Riffer::Messages::Assistant::TextPart.from_hash(part.to_h)).must_equal part
    end

    it "returns a part unchanged" do
      part = Riffer::Messages::Assistant::TextPart.new("Hi")

      expect(Riffer::Messages::Assistant::TextPart.from_hash(part)).must_be_same_as part
    end
  end

  describe "equality" do
    it "compares by value" do
      first = Riffer::Messages::Assistant::TextPart.new("Hi", format: "mock-v1")
      second = Riffer::Messages::Assistant::TextPart.new("Hi", format: "mock-v1")

      expect(first).must_equal second
      expect(first.hash).must_equal second.hash
      expect(first).wont_equal Riffer::Messages::Assistant::TextPart.new("Hi")
    end
  end
end
