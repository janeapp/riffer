# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::ReasoningPart do
  describe "#initialize" do
    it "stores every field" do
      part = Riffer::Messages::ReasoningPart.new(
        type: :encrypted,
        text: "Thinking",
        data: "ciphertext",
        signature: "sig",
        id: "rs_1",
        format: "mock-v1",
      )

      expect(part.type).must_equal :encrypted
      expect(part.text).must_equal "Thinking"
      expect(part.data).must_equal "ciphertext"
      expect(part.signature).must_equal "sig"
      expect(part.id).must_equal "rs_1"
      expect(part.format).must_equal "mock-v1"
    end

    it "defaults the optional fields to nil" do
      part = Riffer::Messages::ReasoningPart.new(type: :text)

      expect(part.text).must_be_nil
      expect(part.data).must_be_nil
      expect(part.signature).must_be_nil
      expect(part.id).must_be_nil
      expect(part.format).must_be_nil
    end

    it "accepts every supported type" do
      types = Riffer::Messages::ReasoningPart::TYPES.map do |type|
        Riffer::Messages::ReasoningPart.new(type: type).type
      end

      expect(types).must_equal %i[text summary encrypted]
    end

    it "raises on a type outside the vocabulary" do
      error = expect { Riffer::Messages::ReasoningPart.new(type: :bogus) }.must_raise(Riffer::ArgumentError)

      expect(error.message).must_include ":bogus"
      expect(error.message).must_include ":encrypted"
    end
  end

  describe ".from_hash" do
    it "builds a part from a hash with a symbol type" do
      part = Riffer::Messages::ReasoningPart.from_hash(type: :summary, text: "Digest", format: "mock-v1")

      expect(part.type).must_equal :summary
      expect(part.text).must_equal "Digest"
      expect(part.format).must_equal "mock-v1"
    end

    it "builds a part from a hash with a string type" do
      part = Riffer::Messages::ReasoningPart.from_hash(type: "encrypted", data: "ciphertext")

      expect(part.type).must_equal :encrypted
      expect(part.data).must_equal "ciphertext"
    end

    it "returns a part unchanged" do
      part = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking")

      expect(Riffer::Messages::ReasoningPart.from_hash(part)).must_be_same_as part
    end

    it "raises on a hash with an unsupported type" do
      expect { Riffer::Messages::ReasoningPart.from_hash(type: "bogus") }.must_raise(Riffer::ArgumentError)
    end
  end

  describe "#to_h" do
    it "omits the fields the part doesn't carry" do
      part = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking")

      expect(part.to_h).must_equal({ type: :text, text: "Thinking" })
    end

    it "includes every field the part carries" do
      part = Riffer::Messages::ReasoningPart.new(
        type: :encrypted,
        data: "ciphertext",
        signature: "sig",
        id: "rs_1",
        format: "mock-v1",
      )

      expect(part.to_h).must_equal(
        { type: :encrypted, data: "ciphertext", signature: "sig", id: "rs_1", format: "mock-v1" },
      )
    end

    it "round-trips through from_hash" do
      part = Riffer::Messages::ReasoningPart.new(type: :summary, text: "Digest", id: "rs_1", format: "mock-v1")

      expect(Riffer::Messages::ReasoningPart.from_hash(part.to_h)).must_equal part
    end
  end

  describe "#==" do
    it "is equal to a part with the same fields" do
      part = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking", format: "mock-v1")
      other = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking", format: "mock-v1")

      expect(part).must_equal other
      expect(part.eql?(other)).must_equal true
      expect(part.hash).must_equal other.hash
    end

    it "differs when any field differs" do
      part = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking")
      other = Riffer::Messages::ReasoningPart.new(type: :summary, text: "Thinking")

      expect(part).wont_equal other
    end

    it "is not equal to a non-part" do
      part = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking")

      expect(part == { type: :text, text: "Thinking" }).must_equal false
    end

    it "dedupes equal parts in a set" do
      part = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking")
      other = Riffer::Messages::ReasoningPart.new(type: :text, text: "Thinking")

      expect([part, other].uniq.size).must_equal 1
    end
  end
end
