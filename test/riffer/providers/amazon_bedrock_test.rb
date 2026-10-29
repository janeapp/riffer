# frozen_string_literal: true

require "test_helper"
require "aws-sdk-bedrockruntime"

describe Riffer::Providers::AmazonBedrock do
  before do
    Riffer.config.amazon_bedrock.api_token = "test_api_token"
    Riffer.config.amazon_bedrock.region = "us-east-1"
  end

  after do
    Riffer.config.amazon_bedrock.api_token = nil
    Riffer.config.amazon_bedrock.region = nil
    Riffer.config.amazon_bedrock.client = nil
  end

  # The SDK's stubbed client validates each request against the Converse shapes.
  def stub_converse(content: [{ text: "OK" }])
    client = Aws::BedrockRuntime::Client.new(stub_responses: true, region: "us-east-1")
    client.stub_responses(
      :converse,
      {
        output: { message: { role: "assistant", content: content } },
        stop_reason: "end_turn",
        usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 },
        metrics: { latency_ms: 1 },
      },
    )
    Riffer.config.amazon_bedrock.client = client
    client
  end

  def stub_stream_events(events)
    stream_double = Object.new
    stream_double.define_singleton_method(:on_event) { |&block| events.each { |e| block.call(e) } }
    client_double = Object.new
    client_double.define_singleton_method(:converse_stream) { |**_kwargs, &block| block.call(stream_double) }
    Riffer.config.amazon_bedrock.client = client_double
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::AmazonBedrock.semconv_provider_name).must_equal "aws.bedrock"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new }

    it "normalizes end_turn to stop" do
      expect(provider.send(:build_finish_reason, "end_turn").reason).must_equal :stop
    end

    it "normalizes max_tokens to length" do
      expect(provider.send(:build_finish_reason, "max_tokens").reason).must_equal :length
    end

    it "normalizes tool_use to tool_calls" do
      expect(provider.send(:build_finish_reason, "tool_use").reason).must_equal :tool_calls
    end

    it "normalizes guardrail_intervened to content_filter" do
      expect(provider.send(:build_finish_reason, "guardrail_intervened").reason).must_equal :content_filter
    end

    it "normalizes content_filtered to content_filter" do
      expect(provider.send(:build_finish_reason, "content_filtered").reason).must_equal :content_filter
    end

    it "normalizes malformed_model_output to malformed_output" do
      expect(provider.send(:build_finish_reason, "malformed_model_output").reason).must_equal :malformed_output
    end

    it "normalizes malformed_tool_use to malformed_output" do
      expect(provider.send(:build_finish_reason, "malformed_tool_use").reason).must_equal :malformed_output
    end

    it "normalizes model_context_window_exceeded to context_window" do
      expect(provider.send(:build_finish_reason, "model_context_window_exceeded").reason).must_equal :context_window
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:build_finish_reason, "mystery")

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "mystery"]
    end

    it "returns nil without a stop reason" do
      expect(provider.send(:build_finish_reason, nil)).must_be_nil
    end
  end

  describe ".skills_adapter" do
    it "returns XmlAdapter for a bare anthropic.* model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("anthropic.claude-3-5-sonnet-20241022-v2:0")

      expect(adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns XmlAdapter for a cross-region us.anthropic.* model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("us.anthropic.claude-sonnet-4-6")

      expect(adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns XmlAdapter for a cross-region eu.anthropic.* model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("eu.anthropic.claude-haiku-4-5-20251001-v1:0")

      expect(adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns MarkdownAdapter for a non-Anthropic model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("us.amazon.nova-lite-v1:0")

      expect(adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "returns MarkdownAdapter for a Meta model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("meta.llama3-70b-instruct-v1:0")

      expect(adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "returns MarkdownAdapter when model is nil" do
      expect(Riffer::Providers::AmazonBedrock.skills_adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "does not match a stray 'anthropic' substring without a dot boundary" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("panthropic-foo")

      expect(adapter).must_equal Riffer::Skills::MarkdownAdapter
    end
  end

  describe "#initialize" do
    it "creates the provider" do
      provider = Riffer::Providers::AmazonBedrock.new

      expect(provider).must_be_instance_of Riffer::Providers::AmazonBedrock
    end

    it "takes no arguments" do
      expect { Riffer::Providers::AmazonBedrock.new(region: "us-east-1") }.must_raise ArgumentError
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::AmazonBedrock.new(retry_limit: 60) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "sets the configured region on the client it builds" do
      expect(Riffer::Providers::AmazonBedrock.new.send(:client).config.region).must_equal "us-east-1"
    end

    it "builds a client without an api_token" do
      Riffer.config.amazon_bedrock.api_token = nil

      expect(Riffer::Providers::AmazonBedrock.new.send(:client).config.region).must_equal "us-east-1"
    end

    it "uses the configured client" do
      configured = Object.new
      Riffer.config.amazon_bedrock.client = configured

      expect(Riffer::Providers::AmazonBedrock.new.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.amazon_bedrock.client = -> { calls += 1 }
      provider = Riffer::Providers::AmazonBedrock.new

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      provider = Riffer::Providers::AmazonBedrock.new

      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "prefers a configured client over configured credentials" do
      configured = Object.new
      Riffer.config.amazon_bedrock.client = configured

      expect(Riffer::Providers::AmazonBedrock.new.send(:client)).must_be_same_as configured
    end

    it "lets the built client resolve the region from AWS_REGION" do
      original = ENV.fetch("AWS_REGION", nil)
      ENV["AWS_REGION"] = "eu-central-1"
      Riffer.config.amazon_bedrock.region = nil

      expect(Riffer::Providers::AmazonBedrock.new.send(:client).config.region).must_equal "eu-central-1"
    ensure
      ENV["AWS_REGION"] = original
    end

    it "prefers a configured region over AWS_REGION" do
      original = ENV.fetch("AWS_REGION", nil)
      ENV["AWS_REGION"] = "eu-central-1"

      expect(Riffer::Providers::AmazonBedrock.new.send(:client).config.region).must_equal "us-east-1"
    ensure
      ENV["AWS_REGION"] = original
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }
    let(:model) { "us.anthropic.claude-haiku-4-5-20251001-v1:0" }

    # Run normalizes tags to String=>String before they reach the provider.
    it "maps all tags (including the reserved user_id) to request_metadata" do
      params = provider.send(
        :build_request_params,
        messages,
        model,
        { tags: { "team" => "growth", "user_id" => "u_1" } },
      )

      expect(params[:request_metadata]).must_equal({ "team" => "growth", "user_id" => "u_1" })
    end

    it "merges tags over request_metadata set in model_options" do
      params = provider.send(
        :build_request_params,
        messages,
        model,
        { request_metadata: { "env" => "prod", "team" => "ops" }, tags: { "team" => "growth" } },
      )

      expect(params[:request_metadata]).must_equal({ "env" => "prod", "team" => "growth" })
    end

    it "omits request_metadata when no tags are given" do
      params = provider.send(:build_request_params, messages, model, {})

      expect(params.key?(:request_metadata)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, model, { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end
  end

  describe "#extract_content" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new }

    def build_response(content_blocks)
      Aws::BedrockRuntime::Types::ConverseResponse.new(
        output: Aws::BedrockRuntime::Types::ConverseOutput::Message.new(
          message: Aws::BedrockRuntime::Types::Message.new(
            role: "assistant",
            content: content_blocks,
          ),
        ),
      )
    end

    it "concatenates multiple text blocks in order" do
      provider # force SDK load before constructing Aws types below
      # Bedrock splits output across several text blocks when reasoning or
      # tool_use blocks are interleaved, so all text blocks must be preserved.
      response = build_response(
        [
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "Hello "),
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "world"),
        ],
      )

      expect(provider.send(:extract_content, response)).must_equal "Hello world"
    end

    it "ignores tool_use blocks when extracting text" do
      provider # force SDK load before constructing Aws types below
      response = build_response(
        [
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "Answer: "),
          Aws::BedrockRuntime::Types::ContentBlock.new(
            tool_use: Aws::BedrockRuntime::Types::ToolUseBlock.new(
              tool_use_id: "id-1",
              name: "calculator",
              input: {},
            ),
          ),
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "42"),
        ],
      )

      expect(provider.send(:extract_content, response)).must_equal "Answer: 42"
    end
  end

  describe "#stream_text" do
    describe "when the stream emits an exception event" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new }

      {
        InternalServerException: :internal_server_exception,
        ModelStreamErrorException: :model_stream_error_exception,
        ThrottlingException: :throttling_exception,
        ValidationException: :validation_exception,
        ServiceUnavailableException: :service_unavailable_exception,
      }.each do |class_name, event_type|
        it "raises Aws::BedrockRuntime::Errors::#{class_name} for a #{event_type} event" do
          type_klass = Aws::BedrockRuntime::Types.const_get(class_name)
          error_klass = Aws::BedrockRuntime::Errors.const_get(class_name)
          event = type_klass.new(message: "boom", event_type: event_type)
          stub_stream_events([event])

          error = assert_raises(error_klass) do
            provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
          end
          expect(error.message).must_equal "boom"
        end
      end

      it "raises for a model_stream_error_exception mid-stream after content deltas" do
        provider # force SDK load before constructing the Aws types below
        delta_event = Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
          delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: "Hel"),
          content_block_index: 0,
          event_type: :content_block_delta,
        )
        error_event = Aws::BedrockRuntime::Types::ModelStreamErrorException.new(
          message: "model failed",
          original_status_code: 500,
          event_type: :model_stream_error_exception,
        )
        stub_stream_events([delta_event, error_event])

        enum = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")
        assert_raises(Aws::BedrockRuntime::Errors::ModelStreamErrorException) { enum.to_a }
      end

      it "raises for a future exception type not explicitly known (auto-caught by class-name suffix)" do
        # Aws DynamicErrors synthesizes Errors::HypotheticalFutureException on lookup.
        provider
        fake_future_exception_class = Struct.new(:message, :event_type) do
          def self.name
            "Aws::BedrockRuntime::Types::HypotheticalFutureException"
          end
        end
        event = fake_future_exception_class.new("surprise", :hypothetical_future_exception)
        stub_stream_events([event])

        error = assert_raises(Aws::BedrockRuntime::Errors::ServiceError) do
          provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        end
        expect(error).must_be_kind_of Aws::BedrockRuntime::Errors::HypotheticalFutureException
      end

      it "ignores unknown non-exception events (e.g. message_start) without raising" do
        provider # force SDK load before constructing the Aws types below
        message_start = Aws::BedrockRuntime::Types::MessageStartEvent.new(
          role: "assistant",
          event_type: :message_start,
        )
        metadata = Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent.new(
          usage: Aws::BedrockRuntime::Types::TokenUsage.new(
            input_tokens: 5,
            output_tokens: 3,
            total_tokens: 8,
          ),
          event_type: :metadata,
        )
        message_stop = Aws::BedrockRuntime::Types::MessageStopEvent.new(
          stop_reason: "end_turn",
          event_type: :message_stop,
        )
        stub_stream_events([message_start, metadata, message_stop])

        events = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

        expect(usage_done).wont_be_nil
        expect(usage_done.token_usage.input_tokens).must_equal 5
      end
    end

    describe "when the stream ends without a messageStop event" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new }

      it "raises Riffer::IncompleteStreamError for an empty stream" do
        stub_stream_events([])

        error = assert_raises(Riffer::IncompleteStreamError) do
          provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        end

        assert_kind_of Riffer::Error, error
        expect(error.message).must_equal "Bedrock ConverseStream ended without a messageStop event"
      end

      it "raises after yielding the content events it did receive" do
        provider # force SDK load before constructing the Aws types below
        delta_event = Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
          delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: "Hel"),
          content_block_index: 0,
          event_type: :content_block_delta,
        )
        stop_event = Aws::BedrockRuntime::Types::ContentBlockStopEvent.new(
          content_block_index: 0,
          event_type: :content_block_stop,
        )
        stub_stream_events([delta_event, stop_event])

        enum = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")
        events = []

        assert_raises(Riffer::IncompleteStreamError) { enum.each { |e| events << e } }

        expect(events.map(&:class)).must_equal [Riffer::StreamEvents::TextDelta]
        expect(events.first.content).must_equal "Hel"
      end

      # aws-sdk-core turns a `:message-type: error` frame into an EventError
      # instance handed to the on_event block; it is never raised by the SDK.
      it "raises the EventError the SDK delivers as an event" do
        provider # force SDK load before constructing the Aws types below
        event = Aws::Errors::EventError.new(:error, "InternalServerError", "boom")
        stub_stream_events([event])

        error = assert_raises(Aws::Errors::EventError) do
          provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        end

        expect(error.message).must_equal "InternalServerError: boom"
        expect(error.error_code).must_equal "InternalServerError"
        expect(error.error_message).must_equal "boom"
      end

      it "does not raise when a messageStop event arrives" do
        provider # force SDK load before constructing the Aws types below
        message_stop = Aws::BedrockRuntime::Types::MessageStopEvent.new(
          stop_reason: "end_turn",
          event_type: :message_stop,
        )
        stub_stream_events([message_stop])

        events = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        finish_reason_done = events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }

        expect(finish_reason_done).wont_be_nil
        expect(finish_reason_done.finish_reason).must_equal :stop
      end
    end

    describe "a tool call without arguments" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new }

      it "streams ToolCallDone with an empty JSON object" do
        provider # force SDK load before constructing the Aws types below
        events = [
          Aws::BedrockRuntime::Types::ContentBlockStartEvent.new(
            start: Aws::BedrockRuntime::Types::ContentBlockStart.new(
              tool_use: Aws::BedrockRuntime::Types::ToolUseBlockStart.new(tool_use_id: "tooluse_1", name: "get_time"),
            ),
            content_block_index: 0,
            event_type: :content_block_start,
          ),
          Aws::BedrockRuntime::Types::ContentBlockStopEvent.new(content_block_index: 0,
                                                                event_type: :content_block_stop,),
          Aws::BedrockRuntime::Types::MessageStopEvent.new(stop_reason: "tool_use", event_type: :message_stop),
        ]
        stub_stream_events(events)

        done = provider.stream_text(prompt: "What time is it?", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").
          to_a.grep(Riffer::StreamEvents::ToolCallDone)

        expect(done.map(&:arguments)).must_equal ["{}"]
      end
    end

    describe "text delta accumulation" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new }

      # Streamed text accumulates in place with <<, so a frozen seed or a buffer
      # aliased into a delta would corrupt the result.
      it "assembles hundreds of deltas byte-identically to their concatenation" do
        provider # force SDK load before constructing the Aws types below
        deltas = Array.new(500) { |i| format("delta-%<index>03d-%<pad>s ", index: i, pad: "x" * 12) }
        events = deltas.map do |text|
          Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
            delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: text),
            content_block_index: 0,
            event_type: :content_block_delta,
          )
        end
        events << Aws::BedrockRuntime::Types::ContentBlockStopEvent.new(
          content_block_index: 0,
          event_type: :content_block_stop,
        )
        events << Aws::BedrockRuntime::Types::MessageStopEvent.new(
          stop_reason: "end_turn",
          event_type: :message_stop,
        )
        stub_stream_events(events)

        stream_events = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a

        expected = deltas.join
        text_done = stream_events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

        expect(text_done).wont_be_nil
        expect(text_done.content).must_equal expected
        expect(text_done.content.bytesize).must_equal expected.bytesize

        streamed = stream_events.grep(Riffer::StreamEvents::TextDelta).map(&:content)

        expect(streamed).must_equal deltas
        expect(streamed.join).must_equal expected
      end

      it "yields one TextDone joining the text blocks on either side of a tool_use block" do
        provider # force SDK load before constructing the Aws types below
        types = Aws::BedrockRuntime::Types
        text_delta = lambda do |index, text|
          types::ContentBlockDeltaEvent.new(
            delta: types::ContentBlockDelta.new(text: text),
            content_block_index: index,
            event_type: :content_block_delta,
          )
        end
        block_stop = lambda do |index|
          types::ContentBlockStopEvent.new(content_block_index: index, event_type: :content_block_stop)
        end
        tool_use_start = types::ContentBlockStart.new(
          tool_use: types::ToolUseBlockStart.new(tool_use_id: "id-1", name: "calc"),
        )
        stub_stream_events([
                             text_delta.call(0, "Let me "),
                             text_delta.call(0, "check. "),
                             block_stop.call(0),
                             types::ContentBlockStartEvent.new(
                               start: tool_use_start,
                               content_block_index: 1,
                               event_type: :content_block_start,
                             ),
                             types::ContentBlockDeltaEvent.new(
                               delta: types::ContentBlockDelta.new(tool_use: types::ToolUseBlockDelta.new(input: "{}")),
                               content_block_index: 1,
                               event_type: :content_block_delta,
                             ),
                             block_stop.call(1),
                             text_delta.call(2, "The answer "),
                             text_delta.call(2, "is 42."),
                             block_stop.call(2),
                             types::MessageStopEvent.new(stop_reason: "end_turn", event_type: :message_stop),
                           ])

        events = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a

        expect(events.grep(Riffer::StreamEvents::ToolCallDone).map(&:call_id)).must_equal ["id-1"]
        text_done = events.grep(Riffer::StreamEvents::TextDone).map(&:content)

        expect(text_done).must_equal ["Let me check. The answer is 42."]
      end
    end
  end

  describe "reasoning" do
    let(:model) { "us.anthropic.claude-haiku-4-5-20251001-v1:0" }
    let(:provider) { Riffer::Providers::AmazonBedrock.new }
    let(:redacted_bytes) { "\xFF\x00opaque\xFE".b }

    def text_reasoning_block(text, signature)
      Aws::BedrockRuntime::Types::ContentBlock::ReasoningContent.new(
        reasoning_content: Aws::BedrockRuntime::Types::ReasoningContentBlock::ReasoningText.new(
          reasoning_text: Aws::BedrockRuntime::Types::ReasoningTextBlock.new(text: text, signature: signature),
        ),
      )
    end

    def text_block(text)
      Aws::BedrockRuntime::Types::ContentBlock.new(text: text)
    end

    def redacted_reasoning_block(bytes)
      Aws::BedrockRuntime::Types::ContentBlock::ReasoningContent.new(
        reasoning_content: Aws::BedrockRuntime::Types::ReasoningContentBlock::RedactedContent.new(
          redacted_content: bytes,
        ),
      )
    end

    def build_response(content_blocks)
      Aws::BedrockRuntime::Types::ConverseResponse.new(
        output: Aws::BedrockRuntime::Types::ConverseOutput::Message.new(
          message: Aws::BedrockRuntime::Types::Message.new(role: "assistant", content: content_blocks),
        ),
        usage: Aws::BedrockRuntime::Types::TokenUsage.new(input_tokens: 1, output_tokens: 1),
        stop_reason: "end_turn",
      )
    end

    def reasoning_delta(content_block_index, **fields)
      Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
        delta: Aws::BedrockRuntime::Types::ContentBlockDelta::ReasoningContent.new(
          reasoning_content: Aws::BedrockRuntime::Types::ReasoningContentBlockDelta.new(**fields),
        ),
        content_block_index: content_block_index,
        event_type: :content_block_delta,
      )
    end

    def text_delta(content_block_index, text)
      Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
        delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: text),
        content_block_index: content_block_index,
        event_type: :content_block_delta,
      )
    end

    def block_stop(content_block_index)
      Aws::BedrockRuntime::Types::ContentBlockStopEvent.new(
        content_block_index: content_block_index,
        event_type: :content_block_stop,
      )
    end

    def stream_events(events)
      stop = Aws::BedrockRuntime::Types::MessageStopEvent.new(stop_reason: "end_turn", event_type: :message_stop)
      stub_stream_events(events + [stop])
      provider.stream_text(prompt: "Hi", model: model).to_a
    end

    def part(**attributes)
      Riffer::Messages::Assistant::ReasoningPart.new(**attributes)
    end

    def convert(reasoning, content: "42", tool_calls: [])
      assistant = Riffer::Messages::Assistant.new(content, reasoning: reasoning, tool_calls: tool_calls)
      provider.send(:convert_assistant_to_bedrock_format, assistant)
    end

    describe "capturing reasoning content blocks" do
      it "maps reasoning_text onto a text part, keeping its signature" do
        response = build_response([text_reasoning_block("Think", "sig"), text_block("42")])

        expect(provider.send(:extract_reasoning, response).map(&:to_h)).must_equal [
          { type: :text, text: "Think", signature: "sig", format: "bedrock-converse-v1" },
        ]
      end

      it "maps redacted_content onto an encrypted part with Base64 data" do
        response = build_response([redacted_reasoning_block(redacted_bytes)])

        expect(provider.send(:extract_reasoning, response).map(&:to_h)).must_equal [
          { type: :encrypted, data: Base64.strict_encode64(redacted_bytes), format: "bedrock-converse-v1" },
        ]
      end

      it "keeps several reasoning blocks in response order" do
        response = build_response([text_reasoning_block("One", "sig-1"), redacted_reasoning_block(redacted_bytes)])

        expect(provider.send(:extract_reasoning, response).map(&:type)).must_equal %i[text encrypted]
      end

      it "returns no parts when the response carries no reasoning" do
        response = build_response([text_block("42")])

        expect(provider.send(:extract_reasoning, response)).must_equal []
      end

      it "attaches the parts to the assistant message from generate_text" do
        response = build_response([text_reasoning_block("Think", "sig"), text_block("42")])
        client_double = Object.new
        client_double.define_singleton_method(:converse) { |**_kwargs| response }
        provider.instance_variable_set(:@client, client_double)

        result = provider.generate_text(prompt: "Hi", model: model)

        expect(result.content).must_equal "42"
        expect(result.reasoning.map(&:to_h)).must_equal [
          { type: :text, text: "Think", signature: "sig", format: "bedrock-converse-v1" },
        ]
      end
    end

    describe "streaming reasoning deltas" do
      it "accumulates a block's text and signature into one ReasoningDone" do
        events = stream_events(
          [
            reasoning_delta(0, text: "Let me "),
            reasoning_delta(0, text: "think."),
            reasoning_delta(0, signature: "sig"),
            block_stop(0),
          ],
        )

        expect(events.grep(Riffer::StreamEvents::ReasoningDelta).map(&:content)).must_equal ["Let me ", "think."]
        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.to_h }).must_equal [
          { type: :text, text: "Let me think.", signature: "sig", format: "bedrock-converse-v1" },
        ]
      end

      it "captures streamed redacted_content as an encrypted part" do
        events = stream_events(
          [
            reasoning_delta(0, redacted_content: redacted_bytes[0, 3]),
            reasoning_delta(0, redacted_content: redacted_bytes[3..]),
            block_stop(0),
          ],
        )

        expect(events.grep(Riffer::StreamEvents::ReasoningDelta)).must_be_empty
        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.to_h }).must_equal [
          { type: :encrypted, data: Base64.strict_encode64(redacted_bytes), format: "bedrock-converse-v1" },
        ]
      end

      it "emits one part per block and leaves the following text block intact" do
        events = stream_events(
          [
            reasoning_delta(0, text: "First"),
            reasoning_delta(0, signature: "sig-1"),
            block_stop(0),
            reasoning_delta(1, redacted_content: redacted_bytes),
            block_stop(1),
            text_delta(2, "4"),
            text_delta(2, "2"),
            block_stop(2),
          ],
        )

        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.type }).must_equal %i[text encrypted]
        expect(events.grep(Riffer::StreamEvents::TextDone).map(&:content)).must_equal ["42"]
      end
    end

    describe "replaying reasoning" do
      it "sends recognized parts as reasoning_content blocks ahead of text and tool_use, in order" do
        reasoning = [
          part(type: :text, text: "Think", signature: "sig", format: "bedrock-converse-v1"),
          part(type: :encrypted, data: Base64.strict_encode64(redacted_bytes), format: "bedrock-converse-v1"),
        ]
        tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "call_1", name: "get_weather", arguments: "{}")

        content = convert(reasoning, tool_calls: [tool_call])[:content]

        expect(content[0]).must_equal({ reasoning_content: { reasoning_text: { text: "Think", signature: "sig" } } })
        expect(content[1]).must_equal({ reasoning_content: { redacted_content: redacted_bytes } })
        expect(content[2]).must_equal({ text: "42" })
        expect(content[3].keys).must_equal [:tool_use]
      end

      it "restores redacted bytes from a part that went through JSON" do
        captured = provider.send(:extract_reasoning, build_response([redacted_reasoning_block(redacted_bytes)]))
        persisted = captured.map { |p| JSON.parse(p.to_h.to_json, symbolize_names: true) }
        restored = persisted.map { |h| Riffer::Messages::Assistant::ReasoningPart.from_hash(h) }

        replayed = convert(restored)[:content].first

        expect(replayed).must_equal({ reasoning_content: { redacted_content: redacted_bytes } })
      end

      # Signature-only reasoning blocks come back from lossy persistence with no text; the SDK's
      # param validator rejects the request unless text is present.
      it "replays a text part with no text as an empty string that passes SDK param validation" do
        reasoning = [part(type: :text, text: nil, signature: "sig", format: "bedrock-converse-v1")]

        block = convert(reasoning)[:content].first

        expect(block).must_equal({ reasoning_content: { reasoning_text: { text: "", signature: "sig" } } })
        shape = Aws::BedrockRuntime::Client.api.operation(:converse).input
        Aws::ParamValidator.validate!(
          shape,
          { model_id: model, messages: [{ role: "assistant", content: [block] }] },
        )
      end

      # The SDK's stubbed client runs its own param validation and JSON
      # serialization, so this pins the wire shape Converse receives.
      it "round-trips captured reasoning through the SDK onto the next request body" do
        client = stub_converse(
          content: [
            { reasoning_content: { reasoning_text: { text: "Think", signature: "sig" } } },
            { reasoning_content: { redacted_content: redacted_bytes } },
            { text: "42" },
          ],
        )
        question = Riffer::Messages::User.new("Hi")

        first = provider.generate_text(messages: [question], model: model)
        provider.generate_text(messages: [question, first, Riffer::Messages::User.new("Again")], model: model)
        body = JSON.parse(client.api_requests.last[:context].http_request.body.read)

        expect(body["messages"][1]["content"]).must_equal [
          { "reasoningContent" => { "reasoningText" => { "text" => "Think", "signature" => "sig" } } },
          { "reasoningContent" => { "redactedContent" => Base64.strict_encode64(redacted_bytes) } },
          { "text" => "42" },
        ]
      end

      it "skips parts with no format or another adapter's format" do
        reasoning = [
          part(type: :text, text: "legacy"),
          part(type: :text, text: "foreign", signature: "sig", format: "anthropic-claude-v1"),
          part(type: :text, text: "kept", signature: "sig", format: "bedrock-converse-v1"),
        ]

        expect(convert(reasoning)[:content]).must_equal [
          { reasoning_content: { reasoning_text: { text: "kept", signature: "sig" } } },
          { text: "42" },
        ]
      end

      it "omits reasoning_content when no part is replayable" do
        expect(convert([part(type: :text, text: "legacy", format: "mock-v1")])[:content]).must_equal [{ text: "42" }]
      end
    end
  end

  describe "reasoning level" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new }

    it "maps :off to Claude's disabled thinking" do
      expect(provider.send(:default_reasoning_options, :off)).must_equal(
        { additional_model_request_fields: { thinking: { type: "disabled" } } },
      )
    end

    it "maps every other level to Claude's adaptive thinking at that effort" do
      %i[low medium high xhigh max].each do |level|
        fields = { thinking: { type: "adaptive" }, output_config: { effort: level.to_s } }

        expect(provider.send(:default_reasoning_options, level)).must_equal({ additional_model_request_fields: fields })
      end
    end

    describe "with a catalog entry" do
      before { Riffer.config.catalog_files = [REASONING_CATALOG_PATH] }
      after { Riffer.config.catalog_files = [] }

      it "sends the catalog's thinking budget instead of adaptive thinking" do
        client = stub_converse

        provider.generate_text(
          prompt: "17 * 23?",
          model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
          riffer_reasoning_level: :low,
        )
        params = client.api_requests.last[:params]

        expect(params[:additional_model_request_fields]).must_equal(
          { thinking: { type: "enabled", budget_tokens: 1024 } },
        )
        expect(params[:inference_config]).must_equal({ max_tokens: 5120 })
      end

      it "sends the catalog's reasoning fields for a model outside the Claude family" do
        client = stub_converse

        provider.generate_text(prompt: "17 * 23?", model: "us.amazon.nova-2-lite-v1:0", riffer_reasoning_level: :low)

        expect(client.api_requests.last[:params][:additional_model_request_fields]).must_equal(
          { reasoningConfig: { type: "enabled", maxReasoningEffort: "low" } },
        )
      end
    end
  end

  describe "usage" do
    describe "normalization" do
      it "folds cache buckets into input_tokens" do
        provider = Riffer::Providers::AmazonBedrock.new
        response = Aws::BedrockRuntime::Types::ConverseResponse.new(
          usage: Aws::BedrockRuntime::Types::TokenUsage.new(
            input_tokens: 9,
            output_tokens: 16,
            cache_write_input_tokens: 3,
            cache_read_input_tokens: 100,
          ),
        )
        token_usage = provider.send(:extract_token_usage, response)

        expect(token_usage.input_tokens).must_equal 112
      end

      it "treats unreported cache buckets as zero" do
        provider = Riffer::Providers::AmazonBedrock.new
        response = Aws::BedrockRuntime::Types::ConverseResponse.new(
          usage: Aws::BedrockRuntime::Types::TokenUsage.new(input_tokens: 9, output_tokens: 16),
        )
        token_usage = provider.send(:extract_token_usage, response)

        expect(token_usage.input_tokens).must_equal 9
      end
    end
  end

  describe "structured output" do
    it "includes output_config.text_format in request params" do
      provider = Riffer::Providers::AmazonBedrock.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      expect(params[:output_config][:text_format][:type]).must_equal "json_schema"
    end

    it "includes json_schema structure with name" do
      provider = Riffer::Providers::AmazonBedrock.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      expect(params[:output_config][:text_format][:structure][:json_schema][:name]).must_equal "response"
    end

    it "serializes schema as JSON string" do
      provider = Riffer::Providers::AmazonBedrock.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      schema_json = params[:output_config][:text_format][:structure][:json_schema][:schema]

      expect(schema_json).must_be_instance_of String
      parsed = JSON.parse(schema_json)

      expect(parsed["type"]).must_equal "object"
    end

    it "does not include output_config when not configured" do
      provider = Riffer::Providers::AmazonBedrock.new
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "us.anthropic.claude-haiku-4-5-20251001-v1:0", {})

      expect(params.key?(:output_config)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::AmazonBedrock.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      expect(params.key?(:structured_output)).must_equal false
    end
  end

  describe "prompt caching" do
    let(:model) { "us.anthropic.claude-haiku-4-5-20251001-v1:0" }
    let(:provider) { Riffer::Providers::AmazonBedrock.new }
    let(:cache_point) { { cache_point: { type: "default" } } }
    let(:cache_tool) do
      stub_tool("GetWeather") do
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    def tool_call_message(*call_ids)
      Riffer::Messages::Assistant.new(
        "",
        tool_calls: call_ids.map do |call_id|
          Riffer::Messages::Assistant::ToolCall.new(call_id: call_id, name: "get_weather", arguments: "{}")
        end,
      )
    end

    def tool_result_message(call_id)
      Riffer::Messages::Tool.new("Sunny", tool_call_id: call_id, name: "get_weather")
    end

    it "appends a cachePoint after the system array and after the last user text block" do
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })

      expect(params[:system].last).must_equal cache_point
      expect(params[:messages].last[:content]).must_equal [{ text: "Hello" }, cache_point]
    end

    it "places the moving cachePoint after the file parts of the last user message" do
      image_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
      file = Riffer::Messages::User::FilePart.new(data: image_base64, media_type: "image/png")
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Describe", files: [file])]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })
      content = params[:messages].last[:content]

      expect(content.length).must_equal 3
      expect(content[1].key?(:image)).must_equal true
      expect(content.last).must_equal cache_point
    end

    it "places the moving cachePoint as a sibling of a single tool_result block" do
      messages = [
        Riffer::Messages::System.new("Be concise"),
        Riffer::Messages::User.new("Weather?"),
        tool_call_message("tooluse_1"),
        tool_result_message("tooluse_1"),
      ]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })
      content = params[:messages].last[:content]

      expect(content.map(&:keys)).must_equal [[:tool_result], [:cache_point]]
      expect(content.first[:tool_result].key?(:cache_point)).must_equal false
    end

    it "places the moving cachePoint after several merged tool_result blocks" do
      messages = [
        Riffer::Messages::System.new("Be concise"),
        Riffer::Messages::User.new("Weather?"),
        tool_call_message("tooluse_1", "tooluse_2"),
        tool_result_message("tooluse_1"),
        tool_result_message("tooluse_2"),
      ]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })
      content = params[:messages].last[:content]

      expect(content.map(&:keys)).must_equal [[:tool_result], [:tool_result], [:cache_point]]
      expect(content.map { |block| block[:tool_result]&.key?(:cache_point) }).must_equal [false, false, nil]
    end

    it "appends a cachePoint after the tools when there is no system prompt" do
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(
        :build_request_params,
        messages,
        model,
        { cache_control: { type: "ephemeral" }, tools: [cache_tool] },
      )

      expect(params[:tool_config][:tools].last).must_equal cache_point
      expect(params[:messages].last[:content].last).must_equal cache_point
    end

    it "only adds the static cachePoint when there are no messages" do
      messages = [Riffer::Messages::System.new("Be concise")]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })

      expect(params[:system].last).must_equal cache_point
      expect(params[:messages]).must_equal []
    end

    it "translates the ttl onto both cachePoints" do
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(
        :build_request_params,
        messages,
        model,
        { cache_control: { type: "ephemeral", ttl: "1h" } },
      )

      expect(params[:system].last[:cache_point][:ttl]).must_equal "1h"
      expect(params[:messages].last[:content].last[:cache_point][:ttl]).must_equal "1h"
    end

    it "does not pass cache_control through as a top-level param" do
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })

      expect(params.key?(:cache_control)).must_equal false
    end

    it "adds no cachePoint anywhere when caching is not requested" do
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, model, {})

      expect(params[:system].none? { |block| block.key?(:cache_point) }).must_equal true
      expect(params[:messages].last[:content].none? { |block| block.key?(:cache_point) }).must_equal true
    end

    it "keeps the previous step's request as the prefix of the next step of a tool loop" do
      options = { cache_control: { type: "ephemeral" }, tools: [cache_tool] }
      first_step = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Weather?")]

      first = provider.send(:build_request_params, first_step, model, options)
      second = provider.send(
        :build_request_params,
        [*first_step, tool_call_message("tooluse_1"), tool_result_message("tooluse_1")],
        model,
        options,
      )

      expect(second[:system]).must_equal first[:system]
      expect(second[:tool_config]).must_equal first[:tool_config]
      expect(first[:messages].map { |message| message[:content] }).must_equal [[{ text: "Weather?" }, cache_point]]
      expect(second[:messages].map { |message| message[:content].map(&:keys) }).must_equal(
        [[[:text]], [[:tool_use]], [[:tool_result], [:cache_point]]],
      )
    end
  end

  describe "file handling" do
    describe "with an S3 URI" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new }

      it "sends an image as an s3_location source" do
        client = stub_converse
        file = Riffer::Messages::User::FilePart.from_url("s3://riffer-test-bucket/image.png")

        provider.generate_text(prompt: "Describe", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0", files: [file])

        expect(client.api_requests.last[:params][:messages].last[:content].last).must_equal(
          { image: { format: "png", source: { s3_location: { uri: "s3://riffer-test-bucket/image.png" } } } },
        )
      end

      it "sends a document as an s3_location source" do
        client = stub_converse
        file = Riffer::Messages::User::FilePart.new(
          media_type: "application/pdf",
          filename: "report.pdf",
          url: "s3://riffer-test-bucket/report.pdf",
        )

        provider.generate_text(prompt: "Read", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0", files: [file])

        expect(client.api_requests.last[:params][:messages].last[:content].last).must_equal(
          {
            document: {
              format: "pdf",
              name: "report",
              source: { s3_location: { uri: "s3://riffer-test-bucket/report.pdf" } },
            },
          },
        )
      end
    end

    describe "document names" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new }
      let(:pdf_data) { Base64.strict_encode64("%PDF-1.4") }

      def document(filename)
        Riffer::Messages::User::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: filename)
      end

      def document_names(messages)
        params = provider.send(:build_request_params, messages, "us.anthropic.claude-haiku-4-5-20251001-v1:0", {})
        params[:messages].flat_map { |message| message[:content] }.filter_map { |block| block.dig(:document, :name) }
      end

      it "drops the extension and the characters Converse rejects" do
        messages = [Riffer::Messages::User.new("Read these",
                                               files: [document("invoice.pdf"), document("Q3_report  v2.final.pdf")],)]

        expect(document_names(messages)).must_equal ["invoice", "Q3-report v2-final"]
      end

      it "names a document without a filename" do
        messages = [Riffer::Messages::User.new("Read this", files: [document(nil)])]

        expect(document_names(messages)).must_equal ["document"]
      end

      it "numbers repeated names across the conversation" do
        messages = [
          Riffer::Messages::User.new("Read these", files: [document("invoice.pdf"), document("invoice.txt")]),
          Riffer::Messages::Assistant.new("Done."),
          Riffer::Messages::User.new("And this one", files: [document("invoice.pdf")]),
        ]

        expect(document_names(messages)).must_equal ["invoice", "invoice (2)", "invoice (3)"]
      end

      it "keeps names within 200 characters, counter included" do
        long = "#{'a' * 250}.pdf"
        messages = [Riffer::Messages::User.new("Read these", files: [document(long), document(long)])]

        expect(document_names(messages)).must_equal ["a" * 200, "#{'a' * 196} (2)"]
      end
    end

    describe "with unsupported URL source" do
      it "raises FileDownloadsDisabledError for non-S3 URLs when downloads are disabled" do
        provider = Riffer::Providers::AmazonBedrock.new
        file = Riffer::Messages::User::FilePart.from_url("https://example.com/image.png")

        expect do
          provider.generate_text(prompt: "Describe this", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
                                 files: [file],)
        end.
          must_raise Riffer::FileDownloadsDisabledError
      end
    end
  end

  describe "tool schema strict mode" do
    it "applies strict_schema to tool parameters" do
      tool = stub_tool("TestTool") do
        description "A test tool"
        params do
          required :name, String
          optional :age, Integer
        end
      end

      provider = Riffer::Providers::AmazonBedrock.new
      format = provider.send(:convert_tool_to_bedrock_format, tool)
      schema = format[:tool_spec][:input_schema][:json]

      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
    end
  end
end
