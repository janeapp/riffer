# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Gemini do
  let(:api_key) { ENV.fetch("GEMINI_API_KEY", "test_api_key") }

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::Gemini.semconv_provider_name).must_equal "gcp.gemini"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::Gemini.new(api_key: api_key) }

    it "normalizes STOP to stop" do
      expect(provider.send(:build_finish_reason, "STOP", tool_calls: false).reason).must_equal :stop
    end

    it "normalizes STOP to tool_calls when the candidate carries function calls" do
      expect(provider.send(:build_finish_reason, "STOP", tool_calls: true).reason).must_equal :tool_calls
    end

    it "normalizes MAX_TOKENS to length" do
      expect(provider.send(:build_finish_reason, "MAX_TOKENS", tool_calls: false).reason).must_equal :length
    end

    it "normalizes SAFETY to content_filter" do
      expect(provider.send(:build_finish_reason, "SAFETY", tool_calls: false).reason).must_equal :content_filter
    end

    it "normalizes MALFORMED_FUNCTION_CALL to error" do
      expect(provider.send(:build_finish_reason, "MALFORMED_FUNCTION_CALL", tool_calls: false).reason).must_equal :error
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:build_finish_reason, "LANGUAGE", tool_calls: false)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "LANGUAGE"]
    end

    it "returns nil without a finish reason" do
      expect(provider.send(:build_finish_reason, nil, tool_calls: false)).must_be_nil
    end

    it "extracts the finish reason when generating" do
      VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
        result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

        expect(result.finish_reason).must_equal :stop
      end
    end

    it "emits a FinishReasonDone event when streaming" do
      VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
        events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
        done = events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }

        expect(done.finish_reason).must_equal :stop
      end
    end
  end

  describe "#initialize" do
    it "creates Gemini client with an api_key" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)

      expect(provider).must_be_instance_of Riffer::Providers::Gemini
    end

    it "uses default timeouts" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)

      expect(provider.instance_variable_get(:@open_timeout)).must_equal 10
      expect(provider.instance_variable_get(:@read_timeout)).must_equal 60
    end

    it "allows custom timeouts" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key, open_timeout: 5, read_timeout: 30)

      expect(provider.instance_variable_get(:@open_timeout)).must_equal 5
      expect(provider.instance_variable_get(:@read_timeout)).must_equal 30
    end
  end

  describe "model validation" do
    it "raises ArgumentError for model with slashes" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)

      expect do
        provider.generate_text(prompt: "Hello", model: "../admin")
      end.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError for model with spaces" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)

      expect do
        provider.generate_text(prompt: "Hello", model: "gemini 2.5")
      end.must_raise Riffer::ArgumentError
    end

    it "accepts valid model names" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)
      path = provider.send(:api_path, "gemini-2.5-flash-lite", "generateContent")

      expect(path).must_include "v1beta/models/gemini-2.5-flash-lite:generateContent"
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          params = { system: "Be concise", prompt: "Say hello", model: "gemini-2.5-flash-lite" }
          result = provider.generate_text(**params)

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          messages = [
            { role: "system", content: "Be concise" },
            { role: "user", content: "Say hello" },
          ]
          result = provider.generate_text(messages: messages, model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello"),
          ]
          result = provider.generate_text(messages: messages, model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_an_Assistant_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?"),
          ]
          result = provider.generate_text(messages: messages, model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-2.5-flash-lite",
            structured_output: structured_output,
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns non-empty content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-2.5-flash-lite",
            structured_output: structured_output,
          )

          expect(result.content).wont_be_empty
        end
      end

      it "returns valid JSON content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-2.5-flash-lite",
            structured_output: structured_output,
          )
          JSON.parse(result.content)
        end
      end

      it "includes sentiment key" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-2.5-flash-lite",
            structured_output: structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed.key?("sentiment")).must_equal true
        end
      end

      it "includes score key" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-2.5-flash-lite",
            structured_output: structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed.key?("score")).must_equal true
        end
      end
    end

    describe "structured output with nested object" do
      let(:nested_object_prompt) { "Extract the address from: John lives at 123 Main St, Toronto, ON M5V 2T6, Canada" }

      let(:nested_object_structured_output) do
        params = Riffer::Params.new
        params.required(:name, String, description: "Person name")
        params.required(:address, Hash, description: "Mailing address") do
          required :street, String, description: "Street address"
          required :city, String, description: "City"
          optional :postal_code, String, description: "Postal or zip code"
          optional :country, String, description: "Country"
        end
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns valid JSON with nested object keys" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output_nested_object/returns_nested_json") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: nested_object_prompt,
            model: "gemini-2.5-flash-lite",
            structured_output: nested_object_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["name"]).must_include "John"
          expect(parsed["address"]).must_be_instance_of Hash
          expect(parsed["address"]["street"]).must_include "123 Main"
          expect(parsed["address"]["city"]).must_include "Toronto"
        end
      end
    end

    describe "structured output with typed array" do
      let(:typed_array_prompt) { "List 3 tags and 3 scores (0.0-1.0) for: 'Ruby is a great programming language'" }

      let(:typed_array_structured_output) do
        params = Riffer::Params.new
        params.required(:tags, Array, of: String, description: "Descriptive tags")
        params.required(:scores, Array, of: Float, description: "Relevance scores between 0 and 1")
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns valid JSON with typed array content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output_typed_array/returns_typed_arrays") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: typed_array_prompt,
            model: "gemini-2.5-flash-lite",
            structured_output: typed_array_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["tags"].length).must_equal 3
          expect(parsed["scores"].length).must_equal 3
          parsed["tags"].each { |tag| expect(tag).must_be_instance_of String }
          parsed["scores"].each { |score| expect(score).must_be_instance_of Float }
        end
      end
    end

    describe "structured output with array of objects" do
      let(:array_of_objects_prompt) { "List 2 items from an order: a book costing $12.99 and a pen costing $1.50" }

      let(:array_of_objects_structured_output) do
        params = Riffer::Params.new
        params.required(:order_id, String, description: "Order identifier")
        params.required(:items, Array, description: "Line items") do
          required :name, String, description: "Product name"
          required :price, Float, description: "Price in dollars"
          optional :quantity, Integer, description: "Quantity ordered"
        end
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns valid JSON with array of objects content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output_array_of_objects/returns_array_of_objects") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: array_of_objects_prompt,
            model: "gemini-2.5-flash-lite",
            structured_output: array_of_objects_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["order_id"]).must_be_instance_of String
          expect(parsed["items"].length).must_equal 2
          parsed["items"].each do |item|
            expect(item["name"]).must_be_instance_of String
            expect(item["price"]).must_be_instance_of Float
          end
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
          deltas = events.grep(Riffer::StreamEvents::TextDelta)

          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "gemini-2.5-flash-lite",
          )

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "gemini-2.5-flash-lite",
          ).to_a

          expect(events).wont_be_empty
        end
      end
    end
  end

  describe "structured output" do
    it "includes responseMimeType in generationConfig" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite",
                             { structured_output: structured_output })

      expect(result[:generationConfig][:responseMimeType]).must_equal "application/json"
    end

    it "includes responseSchema in generationConfig" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite",
                             { structured_output: structured_output })

      expect(result[:generationConfig][:responseSchema][:type]).must_equal "object"
    end

    it "does not include generationConfig when not configured" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite", {})

      expect(result.key?(:generationConfig)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::Gemini.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite",
                             { structured_output: structured_output })

      expect(result.key?(:structured_output)).must_equal false
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::Gemini.new(api_key: api_key) }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }

    it "does not add a labels field (the Developer API has none)" do
      params = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.key?(:labels)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end

    it "never leaks tags into generationConfig" do
      params = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite",
                             { temperature: 0.5, tags: { "team" => "growth" } })

      expect(params[:generationConfig].key?(:tags)).must_equal false
    end
  end

  describe "per-call tags (end-to-end)" do
    let(:provider) { Riffer::Providers::Gemini.new(api_key: api_key) }

    # Gemini drops tags, so a tagged call must reproduce the untagged request
    # body. Replaying the existing untagged cassette with record: :none means
    # any future leak into the Gemini request changes the body and fails the
    # :body matcher — confirming no regression. No new cassette needed.
    it "sends no tags on the wire, matching the untagged request" do
      VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
                       record: :none,) do
        result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite",
                                        tags: { "user_id" => "u_1", "team" => "growth" },)

        expect(result).must_be_instance_of Riffer::Messages::Assistant
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
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/parses_arguments") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )
          args = JSON.parse(result.tool_calls.first.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end

      it "includes tool call id" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/includes_ids") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.call_id).wont_be_nil
        end
      end
    end

    describe "#generate_text with Tool message in history" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
                                              Riffer::Messages::Assistant::ToolCall.new(call_id: "gemini_call_abc123", name: "get_weather", arguments: '{"city":"Toronto"}'),
                                            ],),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.",
                                       tool_call_id: "gemini_call_abc123", name: "get_weather",),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
                                              Riffer::Messages::Assistant::ToolCall.new(call_id: "gemini_call_abc123", name: "get_weather", arguments: '{"city":"Toronto"}'),
                                            ],),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.",
                                       tool_call_id: "gemini_call_abc123", name: "get_weather",),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(tool_done).wont_be_nil
        end
      end

      it "includes tool name in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_stream_text/tool_call_done_has_name") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(tool_done.name).must_equal "get_weather"
        end
      end

      it "includes arguments in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_stream_text/tool_call_done_has_arguments") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-2.5-flash-lite",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          args = JSON.parse(tool_done.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end
    end
  end

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_Gemini/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

          expect(result.token_usage).wont_be_nil
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done).wont_be_nil
        end
      end
    end

    describe "cache read tokens" do
      it "surfaces cachedContentTokenCount when present" do
        provider = Riffer::Providers::Gemini.new(api_key: api_key)
        usage = provider.send(:extract_token_usage,
                              { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20,
                                                 cachedContentTokenCount: 80, } })

        expect(usage.cache_read_tokens).must_equal 80
      end

      it "leaves cache_read_tokens nil when absent" do
        provider = Riffer::Providers::Gemini.new(api_key: api_key)
        usage = provider.send(:extract_token_usage,
                              { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 } })

        expect(usage.cache_read_tokens).must_be_nil
      end
    end

    describe "thinking tokens" do
      it "folds thoughtsTokenCount into output_tokens" do
        provider = Riffer::Providers::Gemini.new(api_key: api_key)
        usage = provider.send(:extract_token_usage,
                              { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20,
                                                 thoughtsTokenCount: 30, } })

        expect(usage.output_tokens).must_equal 50
      end

      it "keeps output_tokens as candidatesTokenCount when absent" do
        provider = Riffer::Providers::Gemini.new(api_key: api_key)
        usage = provider.send(:extract_token_usage,
                              { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 } })

        expect(usage.output_tokens).must_equal 20
      end
    end
  end

  describe "file handling" do
    let(:image_base64) do
      "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg=="
    end

    describe "#generate_text with image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gemini-2.5-flash-lite", files: [file])

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_Gemini/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Gemini.new(api_key: api_key)
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gemini-2.5-flash-lite", files: [file])

          expect(result.content).wont_be_empty
        end
      end
    end
  end
end
