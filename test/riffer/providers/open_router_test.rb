# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::OpenRouter do
  let(:api_key) { ENV.fetch("OPENROUTER_API_KEY", "test_api_key") }

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::OpenRouter.semconv_provider_name).must_equal "openrouter"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }

    it "normalizes stop" do
      expect(provider.send(:build_finish_reason, :stop).reason).must_equal :stop
    end

    it "normalizes length" do
      expect(provider.send(:build_finish_reason, :length).reason).must_equal :length
    end

    it "normalizes tool_calls" do
      expect(provider.send(:build_finish_reason, :tool_calls).reason).must_equal :tool_calls
    end

    it "normalizes content_filter" do
      expect(provider.send(:build_finish_reason, :content_filter).reason).must_equal :content_filter
    end

    it "normalizes error" do
      expect(provider.send(:build_finish_reason, "error").reason).must_equal :error
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:build_finish_reason, "model_length")

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "model_length"]
    end

    it "returns nil without a finish reason" do
      expect(provider.send(:build_finish_reason, nil)).must_be_nil
    end

    it "extracts the finish reason when generating" do
      VCR.use_cassette("Riffer_Providers_OpenRouter/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
        result = provider.generate_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5")

        expect(result.finish_reason).must_equal :stop
      end
    end

    it "emits a FinishReasonDone event when streaming" do
      VCR.use_cassette("Riffer_Providers_OpenRouter/_stream_text/when_prompt_is_provided/yields_stream_events") do
        events = provider.stream_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5").to_a
        done = events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }

        expect(done.finish_reason).must_equal :stop
      end
    end
  end

  describe "#initialize" do
    it "creates a provider with an api_key kwarg" do
      provider = Riffer::Providers::OpenRouter.new(api_key: api_key)

      expect(provider).must_be_instance_of Riffer::Providers::OpenRouter
    end

    it "falls back to config.openrouter.api_key when no kwarg given" do
      Riffer.config.openrouter.api_key = "config-key"
      provider = Riffer::Providers::OpenRouter.new

      expect(provider).must_be_instance_of Riffer::Providers::OpenRouter
    ensure
      Riffer.config.openrouter.api_key = nil
    end

    it "accepts additional client options" do
      provider = Riffer::Providers::OpenRouter.new(api_key: api_key, timeout: 60)

      expect(provider).must_be_instance_of Riffer::Providers::OpenRouter
    end
  end

  describe "#build_request_params" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }
    let(:user_message) { Riffer::Messages::User.new("Hello") }

    it "includes model and messages" do
      params = provider.send(:build_request_params, [user_message], "anthropic/claude-sonnet-4.6", {})

      expect(params[:model]).must_equal "anthropic/claude-sonnet-4.6"
      expect(params[:messages]).must_equal [{ role: "user", content: "Hello" }]
    end

    it "forwards arbitrary options to the request body" do
      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini",
                             { temperature: 0.5, max_tokens: 100 })

      expect(params[:temperature]).must_equal 0.5
      expect(params[:max_tokens]).must_equal 100
    end

    it "normalises string reasoning to {effort: ...} hash" do
      params = provider.send(:build_request_params, [user_message], "deepseek/deepseek-r1", { reasoning: "high" })

      expect(params[:reasoning]).must_equal({ effort: "high" })
    end

    it "passes hash reasoning through verbatim" do
      params = provider.send(:build_request_params, [user_message], "deepseek/deepseek-r1",
                             { reasoning: { effort: "medium", max_tokens: 5000 } })

      expect(params[:reasoning]).must_equal({ effort: "medium", max_tokens: 5000 })
    end

    it "does not set reasoning when option is nil" do
      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini", {})

      expect(params.key?(:reasoning)).must_equal false
    end

    it "passes OpenRouter `provider` option through verbatim" do
      provider_block = { order: ["anthropic"], allow_fallbacks: false }
      params = provider.send(:build_request_params, [user_message], "anthropic/claude-sonnet-4.6",
                             { provider: provider_block })

      expect(params[:provider]).must_equal provider_block
    end

    it "passes OpenRouter `models` fallback array through verbatim" do
      fallbacks = ["openai/gpt-4o", "anthropic/claude-sonnet-4.6"]
      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini", { models: fallbacks })

      expect(params[:models]).must_equal fallbacks
    end

    it "passes `transforms` array through verbatim" do
      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini",
                             { transforms: ["middle-out"] })

      expect(params[:transforms]).must_equal ["middle-out"]
    end

    it "does not leak structured_output kwarg to the request body" do
      params_obj = Riffer::Params.new
      params_obj.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params_obj)

      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini",
                             { structured_output: structured_output })

      expect(params.key?(:structured_output)).must_equal false
    end

    it "converts structured_output to response_format json_schema" do
      params_obj = Riffer::Params.new
      params_obj.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params_obj)

      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini",
                             { structured_output: structured_output })

      expect(params[:response_format][:type]).must_equal "json_schema"
      expect(params[:response_format][:json_schema][:strict]).must_equal true
    end

    it "does not include response_format when structured_output is omitted" do
      params = provider.send(:build_request_params, [user_message], "openai/gpt-4o-mini", {})

      expect(params.key?(:response_format)).must_equal false
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }

    # Tags arrive already normalized from Run, so these pass clean String maps.
    it "maps all tags to metadata" do
      params = provider.send(:build_request_params, messages, "openai/gpt-4o-mini",
                             { tags: { "team" => "growth", "user_id" => "u_1" } })

      expect(params[:metadata]).must_equal({ "team" => "growth", "user_id" => "u_1" })
    end

    it "maps the reserved user_id to the user field while keeping it in metadata" do
      params = provider.send(:build_request_params, messages, "openai/gpt-4o-mini", { tags: { "user_id" => "u_1" } })

      expect([params[:user], params[:metadata]]).must_equal(["u_1", { "user_id" => "u_1" }])
    end

    it "omits the user field when no user_id tag is present" do
      params = provider.send(:build_request_params, messages, "openai/gpt-4o-mini", { tags: { "team" => "growth" } })

      expect(params.key?(:user)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, "openai/gpt-4o-mini", { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end
  end

  describe "per-call tags (end-to-end)" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }

    # The cassette records the request body OpenRouter receives when tags are
    # passed (all tags as metadata, user_id also as the user field). VCR's :body
    # matcher fails the test if tags ever stop reaching the wire.
    it "forwards per-call tags to the request" do
      VCR.use_cassette("Riffer_Providers_OpenRouter/tags/forwards_metadata_and_user") do
        result = provider.generate_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5",
                                        tags: { "user_id" => "u_1", "team" => "growth" },)

        expect(result).must_be_instance_of Riffer::Messages::Assistant
      end
    end
  end

  describe "tool conversion" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }

    let(:weather_tool) do
      Class.new(Riffer::Tool) do
        identifier "get_weather"
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    it "wraps the tool definition in a function envelope" do
      params = provider.send(:build_request_params, [Riffer::Messages::User.new("hi")], "openai/gpt-4o-mini",
                             { tools: [weather_tool] })
      tool = params[:tools].first

      expect(tool[:type]).must_equal "function"
      expect(tool[:function][:name]).must_equal "get_weather"
      expect(tool[:function][:description]).must_equal "Get the current weather for a city"
    end

    it "applies strict schema to the tool parameters" do
      format = provider.send(:convert_tool_to_chat_completions_format, weather_tool)

      expect(format[:function][:strict]).must_equal true
      expect(format[:function][:parameters][:required]).must_include "city"
    end
  end

  describe "message conversion" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }

    it "maps System messages to role: system" do
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hi")]
      result = provider.send(:convert_messages_to_chat_completions_format, messages)

      expect(result.first).must_equal({ role: "system", content: "Be concise" })
    end

    it "maps User messages with no files to role: user with string content" do
      result = provider.send(:convert_messages_to_chat_completions_format, [Riffer::Messages::User.new("Hi")])

      expect(result.first).must_equal({ role: "user", content: "Hi" })
    end

    it "maps User messages with image files to multi-part content" do
      file = Riffer::Messages::FilePart.new(data: "abc", media_type: "image/png")
      result = provider.send(:convert_messages_to_chat_completions_format,
                             [Riffer::Messages::User.new("Look", files: [file])],)
      content = result.first[:content]

      expect(content.first).must_equal({ type: "text", text: "Look" })
      expect(content.last[:type]).must_equal "image_url"
      expect(content.last[:image_url][:url]).must_equal "data:image/png;base64,abc"
    end

    it "maps Assistant text-only messages to role: assistant with content" do
      result = provider.send(:convert_messages_to_chat_completions_format, [Riffer::Messages::Assistant.new("Hello!")])

      expect(result.first).must_equal({ role: "assistant", content: "Hello!" })
    end

    it "maps Assistant tool calls to the nested tool_calls array shape" do
      assistant = Riffer::Messages::Assistant.new("", tool_calls: [
                                                    Riffer::Messages::Assistant::ToolCall.new(call_id: "call_123", name: "get_weather", arguments: '{"city":"Toronto"}'),
                                                  ],)
      result = provider.send(:convert_messages_to_chat_completions_format, [assistant])
      assistant_msg = result.first

      expect(assistant_msg[:role]).must_equal "assistant"
      tc = assistant_msg[:tool_calls].first

      expect(tc[:id]).must_equal "call_123"
      expect(tc[:type]).must_equal "function"
      expect(tc[:function][:name]).must_equal "get_weather"
      expect(tc[:function][:arguments]).must_equal '{"city":"Toronto"}'
    end

    it "maps Tool messages to role: tool with tool_call_id" do
      tool_msg = Riffer::Messages::Tool.new("15 degrees", tool_call_id: "call_123", name: "get_weather")
      result = provider.send(:convert_messages_to_chat_completions_format, [tool_msg])

      expect(result.first).must_equal({ role: "tool", tool_call_id: "call_123", content: "15 degrees" })
    end
  end

  describe "file conversion" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }

    it "encodes base64 images as a data URL" do
      file = Riffer::Messages::FilePart.new(data: "xyz", media_type: "image/jpeg")
      result = provider.send(:convert_file_part_to_chat_completions_format, file)

      expect(result).must_equal({ type: "image_url", image_url: { url: "data:image/jpeg;base64,xyz" } })
    end

    it "passes through image URLs without re-encoding" do
      file = Riffer::Messages::FilePart.new(url: "https://example.com/cat.png", media_type: "image/png")
      result = provider.send(:convert_file_part_to_chat_completions_format, file)

      expect(result[:image_url][:url]).must_equal "https://example.com/cat.png"
    end

    it "encodes documents under the file content type" do
      file = Riffer::Messages::FilePart.new(data: "pdfdata", media_type: "application/pdf", filename: "doc.pdf")
      result = provider.send(:convert_file_part_to_chat_completions_format, file)

      expect(result[:type]).must_equal "file"
      expect(result[:file][:file_data]).must_equal "data:application/pdf;base64,pdfdata"
      expect(result[:file][:filename]).must_equal "doc.pdf"
    end
  end

  describe "extract_token_usage" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: api_key) }

    # These cases build OpenAI::Models::* objects directly, but the openai gem
    # is only required when the provider is constructed (depends_on "openai").
    # Force construction first so the constants resolve regardless of test order.
    before { provider }

    it "maps Chat Completions prompt_tokens/completion_tokens to Riffer's input/output naming" do
      usage = OpenAI::Models::CompletionUsage.new(prompt_tokens: 42, completion_tokens: 17, total_tokens: 59)
      response = OpenAI::Models::Chat::ChatCompletion.new(usage: usage)

      result = provider.send(:extract_token_usage, response)

      expect(result.input_tokens).must_equal 42
      expect(result.output_tokens).must_equal 17
    end

    it "returns nil when usage is missing" do
      response = OpenAI::Models::Chat::ChatCompletion.new

      expect(provider.send(:extract_token_usage, response)).must_be_nil
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns non-empty content" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5")

          expect(result.content).wont_be_empty
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.stream_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5")

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5").to_a
          deltas = events.grep(Riffer::StreamEvents::TextDelta)

          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "anthropic/claude-haiku-4.5",
          ).to_a

          expect(events).wont_be_empty
        end
      end
    end
  end

  describe "structured output" do
    let(:basic_structured_output) do
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      Riffer::Agent::StructuredOutput.new(params)
    end

    it "returns valid JSON content" do
      VCR.use_cassette("Riffer_Providers_OpenRouter/_generate_text/structured_output/returns_structured_json") do
        provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
        result = provider.generate_text(
          prompt: "Analyze the sentiment of: 'I love this product, it is amazing!'",
          model: "openai/gpt-4o-mini",
          structured_output: basic_structured_output,
        )
        JSON.parse(result.content)
      end
    end

    it "includes sentiment and score keys" do
      VCR.use_cassette("Riffer_Providers_OpenRouter/_generate_text/structured_output/returns_structured_json") do
        provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
        result = provider.generate_text(
          prompt: "Analyze the sentiment of: 'I love this product, it is amazing!'",
          model: "openai/gpt-4o-mini",
          structured_output: basic_structured_output,
        )
        parsed = JSON.parse(result.content)

        expect(parsed.key?("sentiment")).must_equal true
        expect(parsed.key?("score")).must_equal true
      end
    end
  end

  describe "tool calling" do
    let(:weather_tool) do
      Class.new(Riffer::Tool) do
        identifier "get_weather"
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    describe "#generate_text with tools" do
      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic/claude-haiku-4.5",
            tools: [weather_tool],
          )

          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic/claude-haiku-4.5",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic/claude-haiku-4.5",
            tools: [weather_tool],
          )
          args = JSON.parse(result.tool_calls.first.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end

      it "includes tool call id" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic/claude-haiku-4.5",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.call_id).wont_be_nil
        end
      end
    end

    describe "#generate_text with Tool message in history" do
      it "returns Assistant message with content" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
                                              Riffer::Messages::Assistant::ToolCall.new(call_id: "call_abc", name: "get_weather", arguments: '{"city":"Toronto"}'),
                                            ],),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "call_abc",
                                                                                        name: "get_weather",),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "anthropic/claude-haiku-4.5",
            tools: [weather_tool],
          )

          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDone event with correct name and arguments" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic/claude-haiku-4.5",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(tool_done).wont_be_nil
          expect(tool_done.name).must_equal "get_weather"
          args = JSON.parse(tool_done.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end
    end
  end

  describe "file handling" do
    let(:image_base64) do
      "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg=="
    end

    describe "#generate_text with image" do
      it "returns an Assistant message with content" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(
            prompt: "Describe this image briefly",
            model: "openai/gpt-4o-mini",
            files: [file],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
          expect(result.content).wont_be_empty
        end
      end
    end
  end

  describe "reasoning" do
    describe "#stream_text with reasoning enabled" do
      it "yields ReasoningDelta events" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/reasoning/_stream_text/yields_reasoning_delta") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is 7 times 8? Think step by step.",
            model: "deepseek/deepseek-r1",
            reasoning: "low",
          ).to_a
          reasoning_deltas = events.grep(Riffer::StreamEvents::ReasoningDelta)

          expect(reasoning_deltas).wont_be_empty
        end
      end

      it "yields ReasoningDone event" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/reasoning/_stream_text/yields_reasoning_delta") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is 7 times 8? Think step by step.",
            model: "deepseek/deepseek-r1",
            reasoning: "low",
          ).to_a
          reasoning_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ReasoningDone) }

          expect(reasoning_done).wont_be_nil
        end
      end
    end
  end

  describe "usage" do
    describe "#generate_text" do
      it "includes token usage in the response" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5")

          expect(result.token_usage).wont_be_nil
          expect(result.token_usage.input_tokens).must_be :>, 0
          expect(result.token_usage.output_tokens).must_be :>, 0
        end
      end
    end

    describe "#stream_text" do
      it "yields TokenUsageDone event" do
        VCR.use_cassette("Riffer_Providers_OpenRouter/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "anthropic/claude-haiku-4.5").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done).wont_be_nil
          expect(usage_done.token_usage.input_tokens).must_be :>, 0
          expect(usage_done.token_usage.output_tokens).must_be :>, 0
        end
      end
    end

    describe "cache read tokens" do
      it "surfaces cached_tokens from prompt_tokens_details" do
        provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
        response = OpenAI::Models::Chat::ChatCompletion.new(
          usage: OpenAI::Models::CompletionUsage.new(
            prompt_tokens: 580,
            completion_tokens: 54,
            total_tokens: 634,
            prompt_tokens_details: OpenAI::Models::CompletionUsage::PromptTokensDetails.new(cached_tokens: 100),
          ),
        )
        token_usage = provider.send(:extract_token_usage, response)

        expect(token_usage.cache_read_tokens).must_equal 100
      end

      it "leaves cache_read_tokens nil when details are absent" do
        provider = Riffer::Providers::OpenRouter.new(api_key: api_key)
        response = OpenAI::Models::Chat::ChatCompletion.new(
          usage: OpenAI::Models::CompletionUsage.new(prompt_tokens: 580, completion_tokens: 54, total_tokens: 634),
        )
        token_usage = provider.send(:extract_token_usage, response)

        expect(token_usage.cache_read_tokens).must_be_nil
      end
    end
  end

  describe "#stream_text resource cleanup" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: "test") }

    def install_stream_double(provider, stream_double)
      completions_double = Object.new
      completions_double.define_singleton_method(:stream_raw) { |**_kwargs| stream_double }
      chat_double = Object.new
      chat_double.define_singleton_method(:completions) { completions_double }
      client_double = Object.new
      client_double.define_singleton_method(:chat) { chat_double }
      provider.instance_variable_set(:@client, client_double)
    end

    it "calls stream.close when iteration raises mid-stream" do
      close_count = 0
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&_block| raise "kaboom" }
      stream_double.define_singleton_method(:close) { close_count += 1 }
      install_stream_double(provider, stream_double)

      assert_raises(RuntimeError) do
        provider.stream_text(prompt: "Hi", model: "openai/gpt-4o-mini").to_a
      end
      expect(close_count).must_equal 1
    end

    it "calls stream.close exactly once on happy path" do
      close_count = 0
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&_block| }
      stream_double.define_singleton_method(:close) { close_count += 1 }
      install_stream_double(provider, stream_double)

      provider.stream_text(prompt: "Hi", model: "openai/gpt-4o-mini").to_a

      expect(close_count).must_equal 1
    end
  end

  # Stub structs that match the shape my stream code touches on real openai
  # gem ChatCompletionChunk objects. Each has +:reasoning+ as a member so
  # +delta[:reasoning]+ returns nil (rather than raising NameError) for
  # non-reasoning chunks. Defined once in the describe blocks below.
  describe "#stream_text tool-call edge cases" do
    let(:provider) { Riffer::Providers::OpenRouter.new(api_key: "test") }
    let(:fn_struct) { Struct.new(:name, :arguments) }
    let(:tc_struct) { Struct.new(:index, :id, :function) }
    let(:delta_struct) { Struct.new(:content, :reasoning, :tool_calls) }
    let(:choice_struct) { Struct.new(:delta, :finish_reason) }
    let(:chunk_struct) { Struct.new(:choices, :usage) }

    def install_chunks(provider, chunks)
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&block| chunks.each(&block) }
      stream_double.define_singleton_method(:close) {}
      completions_double = Object.new
      completions_double.define_singleton_method(:stream_raw) { |**_kwargs| stream_double }
      chat_double = Object.new
      chat_double.define_singleton_method(:completions) { completions_double }
      client_double = Object.new
      client_double.define_singleton_method(:chat) { chat_double }
      provider.instance_variable_set(:@client, client_double)
    end

    it "flushes accumulated tool calls when the stream ends with finish_reason other than tool_calls" do
      # Simulates a non-compliant upstream that emits a tool call but
      # terminates with finish_reason: "stop". Without the post-loop flush
      # the ToolCallDone event would be lost.
      fn = fn_struct.new(name: "get_weather", arguments: '{"city":"Toronto"}')
      tc = tc_struct.new(index: 0, id: "call_abc", function: fn)
      delta = delta_struct.new(content: nil, reasoning: nil, tool_calls: [tc])
      tool_chunk = chunk_struct.new(choices: [choice_struct.new(delta: delta, finish_reason: nil)], usage: nil)
      stop_chunk = chunk_struct.new(choices: [choice_struct.new(delta: nil, finish_reason: "stop")], usage: nil)
      install_chunks(provider, [tool_chunk, stop_chunk])

      events = provider.stream_text(prompt: "weather?", model: "x/y").to_a
      done_events = events.grep(Riffer::StreamEvents::ToolCallDone)

      expect(done_events.size).must_equal 1
      expect(done_events.first.name).must_equal "get_weather"
      expect(done_events.first.arguments).must_equal '{"city":"Toronto"}'
      expect(done_events.first.call_id).must_equal "call_abc"
    end

    it "assigns distinct fallback ids when multiple tool calls arrive without ids" do
      # Two id-less tool calls at indices 0 and 1 must not collide on the
      # done-event item_id/call_id.
      fn0 = fn_struct.new(name: "tool_a", arguments: "{}")
      fn1 = fn_struct.new(name: "tool_b", arguments: "{}")
      tc0 = tc_struct.new(index: 0, id: nil, function: fn0)
      tc1 = tc_struct.new(index: 1, id: nil, function: fn1)
      delta = delta_struct.new(content: nil, reasoning: nil, tool_calls: [tc0, tc1])
      chunk = chunk_struct.new(choices: [choice_struct.new(delta: delta, finish_reason: "tool_calls")], usage: nil)
      install_chunks(provider, [chunk])

      events = provider.stream_text(prompt: "do things", model: "x/y").to_a
      done_events = events.grep(Riffer::StreamEvents::ToolCallDone)
      item_ids = done_events.map(&:item_id)
      call_ids = done_events.map(&:call_id)

      expect(item_ids).must_equal %w[tool_0 tool_1]
      expect(call_ids).must_equal %w[tool_0 tool_1]
    end
  end

  describe "stream_options merging" do
    it "preserves caller-supplied stream_options while still opting into usage" do
      provider = Riffer::Providers::OpenRouter.new(api_key: "test")

      captured = {}
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&_block| }
      stream_double.define_singleton_method(:close) {}
      completions_double = Object.new
      completions_double.define_singleton_method(:stream_raw) do |**kwargs|
        captured.merge!(kwargs)
        stream_double
      end
      chat_double = Object.new
      chat_double.define_singleton_method(:completions) { completions_double }
      client_double = Object.new
      client_double.define_singleton_method(:chat) { chat_double }
      provider.instance_variable_set(:@client, client_double)

      provider.stream_text(
        prompt: "hi",
        model: "x/y",
        stream_options: { include_obfuscation: false },
      ).to_a

      expect(captured[:stream_options][:include_usage]).must_equal true
      expect(captured[:stream_options][:include_obfuscation]).must_equal false
    end
  end
end
