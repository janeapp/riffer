# frozen_string_literal: true

require "test_helper"

describe Riffer::Wire::Anthropic::Stream do
  let(:tool) do
    stub_tool("Lookup") { description "Look things up" }.tap { |t| t.identifier("crm/lookup") }
  end
  let(:stream) { Riffer::Wire::Anthropic::Stream.new(tools: [tool]) }

  def message_start(usage: { input_tokens: 10, output_tokens: 1 })
    { type: "message_start", message: { id: "msg_1", role: "assistant", content: [], usage: usage } }
  end

  def block_start(index, block) = { type: "content_block_start", index: index, content_block: block }
  def delta(index, delta) = { type: "content_block_delta", index: index, delta: delta }
  def block_stop(index) = { type: "content_block_stop", index: index }

  def message_delta(stop_reason, usage: { output_tokens: 7 })
    { type: "message_delta", delta: { stop_reason: stop_reason, stop_sequence: nil }, usage: usage }
  end

  def feed(*events, finish: true)
    yielded = []
    [message_start, *events, *(finish ? [{ type: "message_stop" }] : [])].each { |e| stream.handle(e, yielded) }
    yielded
  end

  def text_block(index, *chunks)
    [
      block_start(index, { type: "text", text: "" }),
      *chunks.map { |chunk| delta(index, { type: "text_delta", text: chunk }) },
      block_stop(index),
    ]
  end

  it "yields text deltas and one TextDone joining every text block at message stop" do
    events = feed(
      *text_block(0, "Let me ", "check. "),
      block_start(1, { type: "thinking", thinking: "", signature: "" }),
      delta(1, { type: "thinking_delta", thinking: "Hmm" }),
      delta(1, { type: "signature_delta", signature: "sig" }),
      block_stop(1),
      *text_block(2, "The answer ", "is 42."),
      message_delta("end_turn"),
    )

    expect(events.grep(Riffer::StreamEvents::TextDelta).map(&:content)).
      must_equal ["Let me ", "check. ", "The answer ", "is 42."]
    expect(events.grep(Riffer::StreamEvents::TextDone).map(&:content)).must_equal ["Let me check. The answer is 42."]
    expect(events.last).must_be_instance_of Riffer::StreamEvents::TextDone
  end

  it "yields no TextDone when the stream carries no text" do
    expect(feed(message_delta("end_turn")).grep(Riffer::StreamEvents::TextDone)).must_be_empty
  end

  it "yields reasoning deltas and one signed ReasoningDone per thinking block" do
    events = feed(
      block_start(0, { type: "thinking", thinking: "", signature: "" }),
      delta(0, { type: "thinking_delta", thinking: "Let me " }),
      delta(0, { type: "thinking_delta", thinking: "think." }),
      delta(0, { type: "signature_delta", signature: "sig" }),
      block_stop(0),
      block_start(1, { type: "redacted_thinking", data: "opaque" }),
      block_stop(1),
    )

    expect(events.grep(Riffer::StreamEvents::ReasoningDelta).map(&:content)).must_equal ["Let me ", "think."]
    expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.to_h }).must_equal [
      { type: :text, text: "Let me think.", signature: "sig", format: "anthropic-messages-v1" },
      { type: :encrypted, data: "opaque", format: "anthropic-messages-v1" },
    ]
  end

  it "streams a tool call's arguments and finishes it with the decoded name" do
    events = feed(
      block_start(0, { type: "tool_use", id: "toolu_1", name: "crm__lookup", input: {} }),
      delta(0, { type: "input_json_delta", partial_json: '{"id":' }),
      delta(0, { type: "input_json_delta", partial_json: " 7}" }),
      block_stop(0),
      message_delta("tool_use"),
    )

    expect(events.grep(Riffer::StreamEvents::ToolCallDelta).map(&:to_h)).must_equal [
      { role: :assistant, item_id: "toolu_1", name: "crm/lookup", arguments_delta: '{"id":' },
      { role: :assistant, item_id: "toolu_1", name: "crm/lookup", arguments_delta: " 7}" },
    ]
    expect(events.grep(Riffer::StreamEvents::ToolCallDone).map(&:to_h)).must_equal [
      { role: :assistant, item_id: "toolu_1", call_id: "toolu_1", name: "crm/lookup", arguments: '{"id":7}' },
    ]
  end

  it "sends empty tool input as an empty object" do
    events = feed(block_start(0, { type: "tool_use", id: "toolu_1", name: "ping", input: {} }), block_stop(0))

    expect(events.grep(Riffer::StreamEvents::ToolCallDone).first.arguments).must_equal "{}"
  end

  it "reports web search progress without surfacing it as a tool call" do
    events = feed(
      block_start(0, { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: {} }),
      delta(0, { type: "input_json_delta", partial_json: '{"query": "ruby"}' }),
      block_stop(0),
      block_start(1, {
                    type: "web_search_tool_result",
                    tool_use_id: "srvtoolu_1",
                    content: [{ type: "web_search_result", title: "Ruby", url: "https://ruby-lang.org",
                                encrypted_content: "x", }],
                  }),
      block_stop(1),
    )

    expect(events.grep(Riffer::StreamEvents::ToolCallDelta)).must_be_empty
    expect(events.grep(Riffer::StreamEvents::WebSearchStatus).map(&:to_h)).must_equal [
      { role: :assistant, status: "searching", query: "ruby" },
    ]
    expect(events.grep(Riffer::StreamEvents::WebSearchDone).map(&:to_h)).must_equal [
      { role: :assistant, query: "ruby", sources: [{ title: "Ruby", url: "https://ruby-lang.org" }] },
    ]
  end

  it "reports no sources for a web search error result" do
    events = feed(
      block_start(0, {
                    type: "web_search_tool_result",
                    tool_use_id: "srvtoolu_1",
                    content: { type: "web_search_tool_result_error", error_code: "max_uses_exceeded" },
                  }),
      block_stop(0),
    )

    expect(events.grep(Riffer::StreamEvents::WebSearchDone).first.sources).must_equal []
  end

  describe "#finish!" do
    it "returns the accumulated message" do
      feed(
        *text_block(0, "4", "2"),
        block_start(1, { type: "tool_use", id: "toolu_1", name: "crm__lookup", input: {} }),
        delta(1, { type: "input_json_delta", partial_json: '{"id":7}' }),
        block_stop(1),
        message_delta("tool_use", usage: { output_tokens: 9, cache_read_input_tokens: 4 }),
      )
      message = stream.finish!

      expect(message.content).must_equal "42"
      expect(message.tool_calls.map(&:to_h)).must_equal [{ call_id: "toolu_1", name: "crm/lookup",
                                                           arguments: '{"id":7}', }]
      expect(message.finish_reason.reason).must_equal :tool_calls
      expect(message.token_usage.to_h).must_equal({ input_tokens: 14, output_tokens: 9, cache_read_tokens: 4 })
    end

    it "raises IncompleteStreamError when the stream ended without message_stop" do
      feed(*text_block(0, "Hel"), finish: false)

      expect { stream.finish! }.must_raise Riffer::IncompleteStreamError
    end
  end

  it "raises Riffer::Error on an error event" do
    error = expect do
      stream.handle({ type: "error", error: { type: "overloaded_error", message: "Overloaded" } }, [])
    end.must_raise Riffer::Error

    expect(error.message).must_equal "Anthropic stream error (overloaded_error): Overloaded"
  end

  it "ignores ping events" do
    expect(feed({ type: "ping" })).must_be_empty
  end
end
