# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::AnthropicCompatible::MessagesAPI do
  let(:provider_class) do
    Class.new(Riffer::Providers::AnthropicCompatible::MessagesAPI) do
      private

      def build_client
        Riffer::Providers::Anthropic::Client.new(api_key: "secret", base_url: "https://llm.example.test")
      end

      def messages_path(model, stream:) = "models/#{model}:#{stream ? 'streamRawPredict' : 'rawPredict'}"

      def request_body(params, stream:) = { anthropic_version: "vendor-1", **super.except(:model) }
    end
  end
  let(:provider) { provider_class.new }

  it "sends the subclass's path and body when generating" do
    stub = stub_request(:post, "https://llm.example.test/models/claude-x:rawPredict").
      with(body: '{"anthropic_version":"vendor-1","messages":[{"role":"user","content":"Hi"}],"max_tokens":4096}').
      to_return(status: 200, body: '{"content":[{"type":"text","text":"Hello"}],"stop_reason":"end_turn"}')

    result = provider.generate_text(prompt: "Hi", model: "claude-x")

    assert_requested stub
    expect([result.content, result.finish_reason]).must_equal ["Hello", :stop]
  end

  it "sends the subclass's path and body when streaming" do
    events = [
      { type: "message_start", message: { content: [], usage: { input_tokens: 3, output_tokens: 1 } } },
      { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
      { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "Hello" } },
      { type: "content_block_stop", index: 0 },
      { type: "message_delta", delta: { stop_reason: "end_turn" }, usage: { output_tokens: 2 } },
      { type: "message_stop" },
    ]
    stub = stub_request(:post, "https://llm.example.test/models/claude-x:streamRawPredict").
      with(
        body: '{"anthropic_version":"vendor-1","messages":[{"role":"user","content":"Hi"}],"max_tokens":4096,' \
              '"stream":true}',
      ).
      to_return(status: 200, body: events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join)

    stream_events = provider.stream_text(prompt: "Hi", model: "claude-x").to_a

    assert_requested stub
    expect(stream_events.map(&:class)).must_equal [
      Riffer::StreamEvents::TextDelta,
      Riffer::StreamEvents::TextDone,
      Riffer::StreamEvents::FinishReasonDone,
      Riffer::StreamEvents::TokenUsageDone,
    ]
    expect(stream_events.last.token_usage.to_h).must_equal({ input_tokens: 3, output_tokens: 2 })
  end

  it "finishes with :length when max_tokens cuts a streamed tool call off" do
    events = [
      { type: "message_start", message: { content: [], usage: { input_tokens: 3, output_tokens: 1 } } },
      {
        type: "content_block_start",
        index: 0,
        content_block: { type: "tool_use", id: "toolu_1", name: "f", input: {} },
      },
      { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: '{"city": "Tor' } },
      { type: "content_block_stop", index: 0 },
      { type: "message_delta", delta: { stop_reason: "max_tokens" }, usage: { output_tokens: 5 } },
      { type: "message_stop" },
    ]
    stub_request(:post, "https://llm.example.test/models/claude-x:streamRawPredict").
      to_return(status: 200, body: events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join)

    stream_events = provider.stream_text(prompt: "Hi", model: "claude-x").to_a

    expect(stream_events.grep(Riffer::StreamEvents::ToolCallDone).map(&:arguments)).must_equal ['{"city": "Tor']
    expect(stream_events.grep(Riffer::StreamEvents::FinishReasonDone).map(&:finish_reason)).must_equal [:length]
  end

  it "raises IncompleteStreamError when the stream ends without message_stop" do
    stub_request(:post, "https://llm.example.test/models/claude-x:streamRawPredict").
      to_return(status: 200, body: "event: ping\ndata: {\"type\":\"ping\"}\n\n")

    expect { provider.stream_text(prompt: "Hi", model: "claude-x").to_a }.must_raise Riffer::IncompleteStreamError
  end

  it "is not registered as a provider" do
    expect(Riffer::Providers::Repository.key_for(Riffer::Providers::AnthropicCompatible::MessagesAPI)).must_be_nil
  end
end
