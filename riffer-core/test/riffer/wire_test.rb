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

  describe ".replayable_messages" do
    def call(name, arguments = "{}", id: "c_1")
      Riffer::Messages::Assistant::ToolCall.new(call_id: id, name: name, arguments: arguments)
    end

    def result(name)
      Riffer::Messages::Tool.new(
        "Unknown tool", tool_call_id: "c_1", name: name, error: "Unknown tool", error_type: :unknown_tool,
      )
    end

    def replayed_calls(*calls)
      Riffer::Wire.replayable_messages([Riffer::Messages::Assistant.new("", tool_calls: calls)]).first.tool_calls
    end

    it "keeps a readable call as it is" do
      expect(replayed_calls(call("files/read", '{"path":"a.txt"}'))).must_equal [call("files/read", '{"path":"a.txt"}')]
    end

    it "keeps a call without arguments as it is" do
      expect(replayed_calls(call("files/read", ""))).must_equal [call("files/read", "")]
    end

    it "replays unparseable arguments as an empty object" do
      expect(replayed_calls(call("files/read", '{"path":'))).must_equal [call("files/read", "{}")]
    end

    it "replays arguments that aren't a JSON object as an empty object" do
      expect(replayed_calls(call("files/read", "[]"), call("files/read", '"a.txt"', id: "c_2"))).
        must_equal [call("files/read", "{}"), call("files/read", "{}", id: "c_2")]
    end

    it "replays an invalid name as the placeholder" do
      names = [" files/read", "[TOOL_CALLS]files_read", "", "a" * 65]

      expect(replayed_calls(*names.map { |name| call(name) }).map(&:name)).
        must_equal [Riffer::Wire::INVALID_TOOL_NAME] * names.size
    end

    it "renames the result of a call with an invalid name to match it" do
      replayed = Riffer::Wire.replayable_messages([result(" files/read")]).first

      expect(replayed.to_h).must_equal result(Riffer::Wire::INVALID_TOOL_NAME).to_h
    end

    it "keeps the rest of the assistant message" do
      message = Riffer::Messages::Assistant.new(
        id: "m_1",
        parts: [Riffer::Messages::Assistant::TextPart.new("Reading."), call(" files/read", "{")],
        finish_reason: :tool_calls,
      )

      replayed = Riffer::Wire.replayable_messages([message]).first

      expect(replayed.to_h).must_equal message.to_h.merge(
        parts: [
          { part: :text, **Riffer::Messages::Assistant::TextPart.new("Reading.").to_h },
          { part: :tool_call, **call(Riffer::Wire::INVALID_TOOL_NAME).to_h },
        ],
      )
    end

    it "returns readable messages as they are" do
      messages = [
        Riffer::Messages::User.new("Read it"),
        Riffer::Messages::Assistant.new("", tool_calls: [call("files/read")]),
        result("files/read"),
      ]

      Riffer::Wire.replayable_messages(messages).zip(messages).each do |replayed, message|
        expect(replayed).must_be_same_as message
      end
    end

    it "leaves the given messages as they were" do
      messages = [Riffer::Messages::Assistant.new("", tool_calls: [call(" files/read", "{")]), result(" files/read")]
      before = messages.map(&:to_h)
      Riffer::Wire.replayable_messages(messages)

      expect(messages.map(&:to_h)).must_equal before
    end
  end
end
