# frozen_string_literal: true

require "test_helper"
require "json"

describe Riffer::Tracing::Capture do
  describe ".input_messages" do
    it "serializes a user message with a text part" do
      json = Riffer::Tracing::Capture.input_messages([Riffer::Messages::User.new("Hi")])

      expect(JSON.parse(json)).must_equal [{ "role" => "user", "parts" => [{ "type" => "text", "content" => "Hi" }] }]
    end

    it "excludes system messages" do
      messages = [Riffer::Messages::System.new("Be brief"), Riffer::Messages::User.new("Hi")]
      json = Riffer::Tracing::Capture.input_messages(messages)

      expect(JSON.parse(json).map { |message| message["role"] }).must_equal ["user"]
    end

    it "serializes assistant reasoning as a reasoning part" do
      reasoning = Riffer::Messages::Assistant::Reasoning.new("Two plus two", "sig_1", nil)
      json = Riffer::Tracing::Capture.input_messages([Riffer::Messages::Assistant.new("4", reasoning: [reasoning])])

      expect(JSON.parse(json).dig(0, "parts")).must_equal [
        { "type" => "reasoning", "content" => "Two plus two" },
        { "type" => "text", "content" => "4" },
      ]
    end

    it "serializes assistant tool calls with parsed arguments" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(
        call_id: "call_1",
        name: "weather",
        arguments: '{"city":"Toronto"}',
      )
      json = Riffer::Tracing::Capture.input_messages([Riffer::Messages::Assistant.new("", tool_calls: [tool_call])])

      expect(JSON.parse(json)).must_equal [{
        "role" => "assistant",
        "parts" => [{ "type" => "tool_call", "id" => "call_1", "name" => "weather",
                      "arguments" => { "city" => "Toronto" }, }],
      }]
    end

    it "passes unparseable tool-call arguments through verbatim" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "call_1", name: "weather", arguments: "not json")
      json = Riffer::Tracing::Capture.input_messages([Riffer::Messages::Assistant.new("", tool_calls: [tool_call])])

      expect(JSON.parse(json).dig(0, "parts", 0, "arguments")).must_equal "not json"
    end

    it "serializes tool messages as tool_call_response parts" do
      message = Riffer::Messages::Tool.new("22C", tool_call_id: "call_1", name: "weather")
      json = Riffer::Tracing::Capture.input_messages([message])

      expect(JSON.parse(json)).must_equal [{
        "role" => "tool",
        "parts" => [{ "type" => "tool_call_response", "id" => "call_1", "response" => "22C" }],
      }]
    end

    it "serializes file parts as metadata-only stubs" do
      file = Riffer::Messages::FilePart.from_hash({ data: "aGVsbG8=", media_type: "image/png", filename: "photo.png" })
      json = Riffer::Tracing::Capture.input_messages([Riffer::Messages::User.new("Look", files: [file])])

      part = JSON.parse(json).dig(0, "parts", 1)

      expect(part).must_equal({ "type" => "file", "media_type" => "image/png", "name" => "photo.png" })
    end
  end

  describe ".system_instructions" do
    it "serializes system message content as text parts" do
      json = Riffer::Tracing::Capture.system_instructions([Riffer::Messages::System.new("Be brief"), Riffer::Messages::User.new("Hi")])

      expect(JSON.parse(json)).must_equal [{ "type" => "text", "content" => "Be brief" }]
    end

    it "returns nil when there are no system messages" do
      expect(Riffer::Tracing::Capture.system_instructions([Riffer::Messages::User.new("Hi")])).must_be_nil
    end
  end

  describe ".output_messages" do
    it "serializes content, tool calls, and the finish reason" do
      tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "call_1", name: "weather", arguments: "{}")
      json = Riffer::Tracing::Capture.output_messages(
        content: "Checking",
        tool_calls: [tool_call],
        finish_reason: :tool_calls,
      )

      expect(JSON.parse(json)).must_equal [{
        "role" => "assistant",
        "parts" => [
          { "type" => "text", "content" => "Checking" },
          { "type" => "tool_call", "id" => "call_1", "name" => "weather", "arguments" => {} },
        ],
        "finish_reason" => "tool_calls",
      }]
    end

    it "omits the finish reason when nil" do
      json = Riffer::Tracing::Capture.output_messages(content: "Hello", tool_calls: [], finish_reason: nil)

      expect(JSON.parse(json).first).wont_include "finish_reason"
    end

    it "omits the text part when content is empty" do
      json = Riffer::Tracing::Capture.output_messages(content: "", tool_calls: [], finish_reason: :stop)

      expect(JSON.parse(json).dig(0, "parts")).must_equal []
    end

    it "emits the reasoning part before the text part" do
      reasoning = Riffer::Messages::Assistant::Reasoning.new("Two plus two", "sig_1", nil)
      json = Riffer::Tracing::Capture.output_messages(
        content: "4",
        tool_calls: [],
        finish_reason: :stop,
        reasoning: [reasoning],
      )

      expect(JSON.parse(json).dig(0, "parts")).must_equal [
        { "type" => "reasoning", "content" => "Two plus two" },
        { "type" => "text", "content" => "4" },
      ]
    end

    it "never captures a signature or a redacted payload" do
      reasoning = [
        Riffer::Messages::Assistant::Reasoning.new("Two plus two", "sig_1", nil),
        Riffer::Messages::Assistant::Reasoning.new(nil, nil, "encrypted-bytes"),
      ]
      json = Riffer::Tracing::Capture.output_messages(
        content: "4",
        tool_calls: [],
        finish_reason: :stop,
        reasoning: reasoning,
      )

      expect(json).wont_include "sig_1"
      expect(json).wont_include "encrypted-bytes"
    end

    it "skips a reasoning block with no text" do
      reasoning = Riffer::Messages::Assistant::Reasoning.new("", nil, "encrypted-bytes")
      json = Riffer::Tracing::Capture.output_messages(
        content: "4",
        tool_calls: [],
        finish_reason: :stop,
        reasoning: [reasoning],
      )

      expect(JSON.parse(json).dig(0, "parts")).must_equal [{ "type" => "text", "content" => "4" }]
    end
  end
end
