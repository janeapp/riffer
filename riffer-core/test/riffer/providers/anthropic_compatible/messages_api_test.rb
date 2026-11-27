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
    expect(stream_events.grep(Riffer::StreamEvents::TextDone)).must_be_empty
  end

  it "raises IncompleteStreamError when the stream ends without message_stop" do
    stub_request(:post, "https://llm.example.test/models/claude-x:streamRawPredict").
      to_return(status: 200, body: "event: ping\ndata: {\"type\":\"ping\"}\n\n")

    expect { provider.stream_text(prompt: "Hi", model: "claude-x").to_a }.must_raise Riffer::IncompleteStreamError
  end

  it "is not registered as a provider" do
    expect(Riffer::Providers::Repository.key_for(Riffer::Providers::AnthropicCompatible::MessagesAPI)).must_be_nil
  end

  describe "deferred tools" do
    let(:find_tools) { stub_tool("FindTools") { description "Find more tools" } }
    let(:list_events) do
      stub_tool("ListEvents") do
        identifier "calendar/list_events"
        description "List calendar events"
        params { required :date, :string }
      end
    end
    let(:send_invoice) { stub_tool("SendInvoice") { description "Send an invoice" } }
    let(:question) { Riffer::Messages::User.new("What's on my calendar?") }

    def loaded_history(*names)
      call = Riffer::Messages::Assistant::ToolCall.new(call_id: "toolu_1", name: "find_tools", arguments: "{}")
      [
        question,
        Riffer::Messages::Assistant.new("", tool_calls: [call]),
        Riffer::Messages::Tool.new("", tool_call_id: "toolu_1", name: "find_tools", loaded_tools: names),
      ]
    end

    def request(messages, deferred_tools: [list_events, send_invoice], **options)
      provider.send(:build_request_params, messages, "claude-x",
                    { tools: [find_tools], deferred_tools: deferred_tools, **options })
    end

    it "sends every deferred tool after the other tools with defer_loading, and no deferred_tools key" do
      params = request([question], web_search: true)

      expect(params[:tools].map { |tool| [tool[:name], tool[:defer_loading]] }).must_equal [
        ["find_tools", nil],
        ["web_search", nil],
        ["calendar__list_events", true],
        ["send_invoice", true],
      ]
      expect(params.key?(:deferred_tools)).must_equal false
    end

    it "sends the same tools after a load" do
      before_load = request([question])
      after_load = request(loaded_history("calendar/list_events"))

      expect(after_load[:tools]).must_equal before_load[:tools]
    end

    it "sends a load as tool_reference blocks under the wire names" do
      params = request(loaded_history("calendar/list_events", "send_invoice"))

      expect(params[:messages].last[:content]).must_equal [{
        type: "tool_result",
        tool_use_id: "toolu_1",
        content: [
          { type: "tool_reference", tool_name: "calendar__list_events" },
          { type: "tool_reference", tool_name: "send_invoice" },
        ],
      }]
    end

    it "references only tools the request defers" do
      params = request(loaded_history("calendar/list_events", "archived_tool"), deferred_tools: [list_events])

      expect(params[:messages].last[:content].first[:content]).must_equal [
        { type: "tool_reference", tool_name: "calendar__list_events" },
      ]
    end

    it "sends the text content when the load names no deferred tool" do
      params = request(loaded_history("archived_tool"))

      expect(params[:messages].last[:content].first[:content]).must_equal ""
    end

    it "decodes a call to a loaded deferred tool" do
      stub_request(:post, "https://llm.example.test/models/claude-x:rawPredict").
        to_return(status: 200, body: {
          content: [{ type: "tool_use", id: "toolu_2", name: "calendar__list_events", input: { date: "2026-11-06" } }],
          stop_reason: "tool_use",
        }.to_json,)

      result = provider.generate_text(prompt: "Hi", model: "claude-x", tools: [find_tools],
                                      deferred_tools: [list_events],)

      expect(result.tool_calls.map(&:name)).must_equal ["calendar/list_events"]
    end

    it "decodes a streamed call to a loaded deferred tool" do
      events = [
        { type: "message_start", message: { content: [], usage: { input_tokens: 3, output_tokens: 1 } } },
        {
          type: "content_block_start",
          index: 0,
          content_block: { type: "tool_use", id: "toolu_2", name: "calendar__list_events", input: {} },
        },
        { type: "content_block_delta", index: 0,
          delta: { type: "input_json_delta", partial_json: '{"date":"2026-11-06"}' }, },
        { type: "content_block_stop", index: 0 },
        { type: "message_delta", delta: { stop_reason: "tool_use" }, usage: { output_tokens: 5 } },
        { type: "message_stop" },
      ]
      stub_request(:post, "https://llm.example.test/models/claude-x:streamRawPredict").
        to_return(status: 200, body: events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join)

      stream_events = provider.stream_text(prompt: "Hi", model: "claude-x", tools: [find_tools],
                                           deferred_tools: [list_events],).to_a

      expect(stream_events.grep(Riffer::StreamEvents::ToolCallDelta).map(&:name)).must_equal ["calendar/list_events"]
      expect(stream_events.grep(Riffer::StreamEvents::ToolCallDone).map { |e| [e.name, e.arguments] }).
        must_equal [["calendar/list_events", '{"date":"2026-11-06"}']]
    end
  end

  describe "file conversion" do
    it "sends a raw bytes file as a base64 source" do
      file = Riffer::Messages::User::FilePart.new(bytes: "png-bytes", media_type: "image/png")
      result = provider.send(:convert_file_part, file)

      source = { type: "base64", media_type: "image/png", data: Base64.strict_encode64("png-bytes") }

      expect(result).must_equal({ type: "image", source: source })
    end

    it "sends inline data instead of a url when a file has both" do
      file = Riffer::Messages::User::FilePart.new(data: "aGVsbG8=", url: "https://example.com/a.png",
                                                  media_type: "image/png",)
      result = provider.send(:convert_file_part, file)

      expect(result[:source]).must_equal({ type: "base64", media_type: "image/png", data: "aGVsbG8=" })
    end

    it "sends a url-only file as a url source" do
      file = Riffer::Messages::User::FilePart.from_url("https://example.com/a.png")
      result = provider.send(:convert_file_part, file)

      expect(result[:source]).must_equal({ type: "url", url: "https://example.com/a.png" })
    end

    %w[image/jpeg image/png image/gif image/webp].each do |media_type|
      it "sends #{media_type} as a base64 image" do
        file = Riffer::Messages::User::FilePart.new(bytes: "image-bytes", media_type: media_type)
        result = provider.send(:convert_file_part, file)

        source = { type: "base64", media_type: media_type, data: Base64.strict_encode64("image-bytes") }

        expect(result).must_equal({ type: "image", source: source })
      end
    end

    it "sends a PDF as a base64 document" do
      file = Riffer::Messages::User::FilePart.new(bytes: "%PDF-1.7", media_type: "application/pdf")
      result = provider.send(:convert_file_part, file)

      source = { type: "base64", media_type: "application/pdf", data: Base64.strict_encode64("%PDF-1.7") }

      expect(result).must_equal({ type: "document", source: source })
    end

    it "sends a url-only PDF as a url source" do
      file = Riffer::Messages::User::FilePart.from_url("https://example.com/a.pdf")
      result = provider.send(:convert_file_part, file)

      expect(result).must_equal({ type: "document", source: { type: "url", url: "https://example.com/a.pdf" } })
    end

    %w[text/plain text/csv text/html].each do |media_type|
      it "sends #{media_type} as a text/plain text document" do
        file = Riffer::Messages::User::FilePart.new(bytes: "caf\xC3\xA9".b, media_type: media_type)
        result = provider.send(:convert_file_part, file)

        source = { type: "text", media_type: "text/plain", data: "café" }

        expect(result).must_equal({ type: "document", source: source })
        expect(result[:source][:data].encoding).must_equal Encoding::UTF_8
      end
    end

    it "decodes base64 data for a text document" do
      file = Riffer::Messages::User::FilePart.new(data: Base64.strict_encode64("a,b\n1,2\n"), media_type: "text/csv")
      result = provider.send(:convert_file_part, file)

      expect(result[:source]).must_equal({ type: "text", media_type: "text/plain", data: "a,b\n1,2\n" })
    end

    it "leaves the caller's bytes untouched" do
      bytes = "hello".b
      file = Riffer::Messages::User::FilePart.new(bytes: bytes, media_type: "text/plain")
      provider.send(:convert_file_part, file)

      expect(bytes.encoding).must_equal Encoding::BINARY
    end

    it "raises when a text file is not valid UTF-8" do
      file = Riffer::Messages::User::FilePart.new(bytes: "caf\xE9".b, media_type: "text/plain")

      expect { provider.send(:convert_file_part, file) }.must_raise Riffer::FileEncodingError
    end
  end

  describe "#file_delivery" do
    %w[text/plain text/csv text/html].each do |media_type|
      it "downloads #{media_type} as bytes" do
        file = Riffer::Messages::User::FilePart.new(url: "https://example.com/a", media_type: media_type)

        expect(provider.file_delivery(file)).must_equal :bytes
      end
    end

    %w[https://example.com/a.png https://example.com/a.pdf].each do |url|
      it "passes #{url} through" do
        expect(provider.file_delivery(Riffer::Messages::User::FilePart.from_url(url))).must_equal :url
      end
    end
  end

  it "downloads a URL text file and sends it as a text document" do
    Riffer.config.files.allow_downloads = true
    Riffer.config.files.downloader = ->(_url, **) { "INV-4821".b }
    file = Riffer::Messages::User::FilePart.from_url("https://example.com/notes.txt")
    document = { type: "document", source: { type: "text", media_type: "text/plain", data: "INV-4821" } }
    body = { messages: [{ role: "user", content: [{ type: "text", text: "Read this" }, document] }] }
    stub = stub_request(:post, "https://llm.example.test/models/claude-x:rawPredict").
      with(body: hash_including(body)).
      to_return(status: 200, body: '{"content":[{"type":"text","text":"ok"}],"stop_reason":"end_turn"}')

    provider.generate_text(messages: [Riffer::Messages::User.new("Read this", files: [file])], model: "claude-x")

    assert_requested stub
  ensure
    Riffer.config.files.allow_downloads = false
    Riffer.config.files.downloader = Riffer::Files::Downloader.new
  end
end
