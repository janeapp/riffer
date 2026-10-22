# frozen_string_literal: true

require "test_helper"

describe Riffer::Wire do
  let(:tool) do
    Class.new(Riffer::Tool) do
      identifier "files/read"
      description "Reads a file"
    end
  end

  describe ".encode_tool_name" do
    it "replaces slashes with the separator" do
      expect(Riffer::Wire.encode_tool_name("files/read")).must_equal "files__read"
    end
  end

  describe ".decode_tool_name" do
    it "returns the name of the tool whose encoded name matches" do
      expect(Riffer::Wire.decode_tool_name("files__read", tools: [tool])).must_equal "files/read"
    end

    it "returns the wire name when no tool matches" do
      expect(Riffer::Wire.decode_tool_name("unknown__tool", tools: [tool])).must_equal "unknown__tool"
    end
  end

  describe ".parse_tool_arguments" do
    it "parses JSON arguments" do
      expect(Riffer::Wire.parse_tool_arguments('{"path":"a.txt"}')).must_equal({ "path" => "a.txt" })
    end

    it "returns an empty hash for empty arguments" do
      expect(Riffer::Wire.parse_tool_arguments("")).must_equal({})
    end
  end
end
