# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Assistant::ServerToolPart do
  let(:part) do
    Riffer::Messages::Assistant::ServerToolPart.new(
      name: "web_search",
      kind: :call,
      data: '{"type":"server_tool_use"}',
      id: "srvtoolu_1",
      format: "mock-v1",
    )
  end

  describe "#initialize" do
    it "stores every field" do
      expect([part.name, part.kind, part.data, part.id, part.format]).must_equal(
        ["web_search", :call, '{"type":"server_tool_use"}', "srvtoolu_1", "mock-v1"],
      )
    end

    it "accepts every supported kind" do
      kinds = Riffer::Messages::Assistant::ServerToolPart::KINDS.map do |kind|
        Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: kind, data: "{}").kind
      end

      expect(kinds).must_equal %i[call result]
    end

    it "raises Riffer::ArgumentError on an unknown kind" do
      expect do
        Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: :status, data: "{}")
      end.must_raise Riffer::ArgumentError
    end
  end

  describe "#to_h" do
    it "omits the fields it doesn't carry" do
      part = Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: :result, data: "{}")

      expect(part.to_h).must_equal({ name: "web_search", kind: :result, data: "{}" })
    end
  end

  describe ".from_hash" do
    it "round-trips through JSON, turning the kind back into a symbol" do
      reloaded = Riffer::Messages::Assistant::ServerToolPart.from_hash(
        JSON.parse(JSON.generate(part.to_h), symbolize_names: true),
      )

      expect(reloaded).must_equal part
    end

    it "returns a part unchanged" do
      expect(Riffer::Messages::Assistant::ServerToolPart.from_hash(part)).must_be_same_as part
    end
  end

  describe "equality" do
    it "compares by value" do
      copy = Riffer::Messages::Assistant::ServerToolPart.from_hash(part.to_h)

      expect(copy).must_equal part
      expect(copy.hash).must_equal part.hash
    end
  end
end
