# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Gemini do
  let(:api_key) { ENV.fetch("GEMINI_API_KEY", "test_api_key") }

  # Credentials now reach the provider only through config, so every test that
  # builds a client needs one configured.
  before { Riffer.config.gemini.api_key = api_key }

  after do
    Riffer.config.gemini.api_key = nil
    Riffer.config.gemini.client = nil
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::Gemini.semconv_provider_name).must_equal "gcp.gemini"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::Gemini.new }

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

    it "normalizes every safety-style value to content_filter" do
      raws = %w[RECITATION BLOCKLIST PROHIBITED_CONTENT SPII IMAGE_SAFETY IMAGE_PROHIBITED_CONTENT IMAGE_RECITATION
                LANGUAGE]
      reasons = raws.map { |raw| provider.send(:build_finish_reason, raw, tool_calls: false).reason }.uniq

      expect(reasons).must_equal [:content_filter]
    end

    it "normalizes MALFORMED_FUNCTION_CALL and UNEXPECTED_TOOL_CALL to malformed_output" do
      raws = %w[MALFORMED_FUNCTION_CALL UNEXPECTED_TOOL_CALL]
      reasons = raws.map { |raw| provider.send(:build_finish_reason, raw, tool_calls: false).reason }.uniq

      expect(reasons).must_equal [:malformed_output]
    end

    it "normalizes NO_IMAGE to error" do
      expect(provider.send(:build_finish_reason, "NO_IMAGE", tool_calls: false).reason).must_equal :error
    end

    it "normalizes catch-all values to other" do
      raws = %w[TOO_MANY_TOOL_CALLS OTHER IMAGE_OTHER FINISH_REASON_UNSPECIFIED]
      reasons = raws.map { |raw| provider.send(:build_finish_reason, raw, tool_calls: false).reason }.uniq

      expect(reasons).must_equal [:other]
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:build_finish_reason, "MYSTERY", tool_calls: false)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "MYSTERY"]
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
    it "creates the provider" do
      provider = Riffer::Providers::Gemini.new

      expect(provider).must_be_instance_of Riffer::Providers::Gemini
    end

    it "takes no arguments" do
      expect { Riffer::Providers::Gemini.new(api_key: api_key) }.must_raise ArgumentError
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::Gemini.new(open_timeout: 5) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "builds a Gemini::Client from the configured api_key" do
      expect(Riffer::Providers::Gemini.new.send(:client)).must_be_instance_of Riffer::Providers::Gemini::Client
    end

    it "uses the configured client" do
      configured = Object.new
      Riffer.config.gemini.client = configured

      expect(Riffer::Providers::Gemini.new.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.gemini.client = -> { calls += 1 }
      provider = Riffer::Providers::Gemini.new

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      provider = Riffer::Providers::Gemini.new

      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "prefers a configured client over configured credentials" do
      configured = Object.new
      Riffer.config.gemini.client = configured

      expect(Riffer::Providers::Gemini.new.send(:client)).must_be_same_as configured
    end
  end

  describe "model validation" do
    it "raises ArgumentError for model with slashes" do
      provider = Riffer::Providers::Gemini.new

      expect do
        provider.generate_text(prompt: "Hello", model: "../admin")
      end.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError for model with spaces" do
      provider = Riffer::Providers::Gemini.new

      expect do
        provider.generate_text(prompt: "Hello", model: "gemini 2.5")
      end.must_raise Riffer::ArgumentError
    end

    it "accepts valid model names" do
      provider = Riffer::Providers::Gemini.new
      path = provider.send(:api_path, "gemini-2.5-flash-lite", "generateContent")

      expect(path).must_include "v1beta/models/gemini-2.5-flash-lite:generateContent"
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
          params = { system: "Be concise", prompt: "Say hello", model: "gemini-2.5-flash-lite" }
          result = provider.generate_text(**params)

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new
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
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/with_an_Assistant_message/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_nested_object/returns_nested_json",
        ) do
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_array_of_objects/returns_array_of_objects",
        ) do
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
          result = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
          deltas = events.grep(Riffer::StreamEvents::TextDelta)

          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
          result = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "gemini-2.5-flash-lite",
          )

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
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
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(
        :build_request_params,
        messages,
        "gemini-2.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result[:generationConfig][:responseMimeType]).must_equal "application/json"
    end

    it "includes responseSchema in generationConfig" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(
        :build_request_params,
        messages,
        "gemini-2.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result[:generationConfig][:responseSchema][:type]).must_equal "object"
    end

    it "does not include generationConfig when not configured" do
      provider = Riffer::Providers::Gemini.new
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite", {})

      expect(result.key?(:generationConfig)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(
        :build_request_params,
        messages,
        "gemini-2.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result.key?(:structured_output)).must_equal false
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::Gemini.new }
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
      params = provider.send(
        :build_request_params,
        messages,
        "gemini-2.5-flash-lite",
        { temperature: 0.5, tags: { "team" => "growth" } },
      )

      expect(params[:generationConfig].key?(:tags)).must_equal false
    end
  end

  describe "per-call tags (end-to-end)" do
    let(:provider) { Riffer::Providers::Gemini.new }

    # Gemini drops tags, so a tagged call must reproduce the untagged request
    # body. Replaying the existing untagged cassette with record: :none means
    # any future leak into the Gemini request changes the body and fails the
    # :body matcher — confirming no regression. No new cassette needed.
    it "sends no tags on the wire, matching the untagged request" do
      VCR.use_cassette(
        "Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
        record: :none,
      ) do
        result = provider.generate_text(
          prompt: "Say hello",
          model: "gemini-2.5-flash-lite",
          tags: { "user_id" => "u_1", "team" => "growth" },
        )

        expect(result).must_be_instance_of Riffer::Messages::Assistant
      end
    end
  end

  describe "tool calling" do
    let(:weather_tool) do
      stub_tool("GetWeather") do
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    describe "#generate_text with tools" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new(
              "",
              tool_calls: [
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "gemini_call_abc123",
                  name: "get_weather",
                  arguments: '{"city":"Toronto"}',
                ),
              ],
            ),
            Riffer::Messages::Tool.new(
              "The weather in Toronto is 15 degrees Celsius.",
              tool_call_id: "gemini_call_abc123",
              name: "get_weather",
            ),
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
          provider = Riffer::Providers::Gemini.new
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new(
              "",
              tool_calls: [
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "gemini_call_abc123",
                  name: "get_weather",
                  arguments: '{"city":"Toronto"}',
                ),
              ],
            ),
            Riffer::Messages::Tool.new(
              "The weather in Toronto is 15 degrees Celsius.",
              tool_call_id: "gemini_call_abc123",
              name: "get_weather",
            ),
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
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
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

          expect(result.token_usage).wont_be_nil
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-2.5-flash-lite").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done).wont_be_nil
        end
      end
    end

    describe "cache read tokens" do
      it "surfaces cachedContentTokenCount when present" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20, cachedContentTokenCount: 80 } },
        )

        expect(usage.cache_read_tokens).must_equal 80
      end

      it "leaves cache_read_tokens nil when absent" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 } },
        )

        expect(usage.cache_read_tokens).must_be_nil
      end
    end

    describe "thinking tokens" do
      it "folds thoughtsTokenCount into output_tokens" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20, thoughtsTokenCount: 30 } },
        )

        expect(usage.output_tokens).must_equal 50
      end

      it "keeps output_tokens as candidatesTokenCount when absent" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 } },
        )

        expect(usage.output_tokens).must_equal 20
      end
    end
  end

  describe "file handling" do
    let(:image_base64) do
      <<~BASE64.chomp
        iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg==
      BASE64
    end

    describe "#generate_text with image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Gemini.new
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gemini-2.5-flash-lite", files: [file])

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_Gemini/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Gemini.new
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gemini-2.5-flash-lite", files: [file])

          expect(result.content).wont_be_empty
        end
      end
    end
  end
  describe "reasoning" do
    let(:provider) { Riffer::Providers::Gemini.new }
    let(:model) { "gemini-3-flash-preview" }
    let(:weather_tool) do
      stub_tool("GetWeather") do
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    def response_with(parts)
      { candidates: [{ content: { parts: parts }, finishReason: "STOP" }] }
    end

    describe "#extract_content" do
      it "excludes thought parts from the answer" do
        response = response_with(
          [
            { text: "Working through it", thought: true },
            { text: "The answer is 4", thoughtSignature: "sig_1" },
          ],
        )

        expect(provider.send(:extract_content, response)).must_equal "The answer is 4"
      end
    end

    describe "#extract_tool_calls" do
      it "captures the thought signature on the functionCall part" do
        response = response_with(
          [{ functionCall: { name: "get_weather", args: { city: "Toronto" } }, thoughtSignature: "sig_1" }],
        )
        tool_calls = provider.send(:extract_tool_calls, response)

        expect(tool_calls.map(&:signature)).must_equal ["sig_1"]
      end

      it "keeps part order and signs the first of a parallel pair" do
        response = response_with(
          [
            { functionCall: { name: "get_weather", args: { city: "Toronto" } }, thoughtSignature: "sig_1" },
            { functionCall: { name: "get_weather", args: { city: "Tokyo" } } },
          ],
        )
        tool_calls = provider.send(:extract_tool_calls, response)

        expect(tool_calls.map(&:signature)).must_equal ["sig_1", nil]
        expect(tool_calls.map { |tc| JSON.parse(tc.arguments)["city"] }).must_equal %w[Toronto Tokyo]
      end
    end

    describe "#extract_reasoning" do
      it "joins the thought parts into one block signed by the text part" do
        response = response_with(
          [
            { text: "First I check ", thought: true },
            { text: "the forecast", thought: true },
            { text: "It is sunny", thoughtSignature: "sig_1" },
          ],
        )

        expect(provider.send(:extract_reasoning, response).map(&:to_h)).must_equal(
          [{ text: "First I check the forecast", signature: "sig_1", redacted_data: nil, id: nil }],
        )
      end

      it "returns the signature alone when the turn carries no thought summary" do
        response = response_with([{ text: "It is sunny", thoughtSignature: "sig_1" }])

        expect(provider.send(:extract_reasoning, response).map(&:to_h)).must_equal(
          [{ text: "", signature: "sig_1", redacted_data: nil, id: nil }],
        )
      end

      it "returns an empty array without thoughts or a text signature" do
        expect(provider.send(:extract_reasoning, response_with([{ text: "It is sunny" }]))).must_equal []
      end
    end

    describe "#stream_text" do
      let(:stream_url) do
        "https://generativelanguage.googleapis.com/v1beta/models/#{model}:streamGenerateContent?alt=sse"
      end

      def sse(*payloads)
        payloads.map { |payload| "data: #{JSON.generate(payload)}\n\n" }.join
      end

      it "yields thought parts as reasoning and signs one ReasoningDone" do
        stub_request(:post, stream_url).to_return(
          status: 200,
          body: sse(
            response_with([{ text: "Working ", thought: true }]),
            response_with([{ text: "through it", thought: true }]),
            response_with([{ text: "The answer is 4" }]),
            response_with([{ text: "", thoughtSignature: "sig_1" }]),
          ),
        )
        events = provider.stream_text(prompt: "What is 2+2?", model: model).to_a
        done = events.grep(Riffer::StreamEvents::ReasoningDone)

        expect(events.grep(Riffer::StreamEvents::ReasoningDelta).map(&:content)).must_equal ["Working ", "through it"]
        expect(done.map(&:to_h)).must_equal(
          [{ role: :assistant, content: "Working through it", signature: "sig_1" }],
        )
      end

      it "keeps thought text out of the answer and closes reasoning before the text" do
        stub_request(:post, stream_url).to_return(
          status: 200,
          body: sse(
            response_with([{ text: "Working through it", thought: true }]),
            response_with([{ text: "The answer is 4", thoughtSignature: "sig_1" }]),
          ),
        )
        events = provider.stream_text(prompt: "What is 2+2?", model: model).to_a
        text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
        done = events.find { |e| e.is_a?(Riffer::StreamEvents::ReasoningDone) }

        expect(text_done.content).must_equal "The answer is 4"
        expect(events.index(done)).must_be :<, events.index(text_done)
      end

      it "signs a streamed tool call with the thought signature on its part" do
        stub_request(:post, stream_url).to_return(
          status: 200,
          body: sse(
            response_with(
              [{ functionCall: { name: "get_weather", args: { city: "Toronto" } }, thoughtSignature: "sig_1" }],
            ),
          ),
        )
        events = provider.stream_text(prompt: "Weather?", model: model, tools: [weather_tool]).to_a

        expect(events.grep(Riffer::StreamEvents::ToolCallDone).map(&:signature)).must_equal ["sig_1"]
      end
    end

    describe "replay in #build_request_params" do
      def model_parts(message)
        messages = [
          Riffer::Messages::User.new("What is the weather in Toronto?"),
          message,
          Riffer::Messages::User.new("Thanks"),
        ]
        params = provider.send(:build_request_params, messages, model, {})
        params[:contents].find { |content| content[:role] == "model" }[:parts]
      end

      it "replays the thought signature on the functionCall part" do
        tool_call = Riffer::Messages::Assistant::ToolCall.new(
          call_id: "gemini_call_1",
          name: "get_weather",
          arguments: '{"city":"Toronto"}',
          signature: "sig_1",
        )

        expect(model_parts(Riffer::Messages::Assistant.new("", tool_calls: [tool_call]))).must_equal(
          [{ functionCall: { name: "get_weather", args: { "city" => "Toronto" } }, thoughtSignature: "sig_1" }],
        )
      end

      it "keeps part order when only the first of a parallel pair is signed" do
        signed = Riffer::Messages::Assistant::ToolCall.new(
          call_id: "gemini_call_1", name: "get_weather", arguments: '{"city":"Toronto"}', signature: "sig_1",
        )
        unsigned = Riffer::Messages::Assistant::ToolCall.new(
          call_id: "gemini_call_2", name: "get_weather", arguments: '{"city":"Tokyo"}',
        )
        parts = model_parts(Riffer::Messages::Assistant.new("", tool_calls: [signed, unsigned]))

        expect(parts.map { |part| part[:thoughtSignature] }).must_equal ["sig_1", nil]
        expect(parts.map { |part| part[:functionCall][:args]["city"] }).must_equal %w[Toronto Tokyo]
      end

      it "replays the text signature on the first text part and drops the thought text" do
        reasoning = Riffer::Messages::Assistant::Reasoning.new("Working through it", "sig_1", nil, nil)

        expect(model_parts(Riffer::Messages::Assistant.new("It is sunny", reasoning: [reasoning]))).must_equal(
          [{ text: "It is sunny", thoughtSignature: "sig_1" }],
        )
      end

      it "sends no signature when the reasoning is unsigned" do
        reasoning = Riffer::Messages::Assistant::Reasoning.new("Working through it", nil, nil, nil)

        expect(model_parts(Riffer::Messages::Assistant.new("It is sunny", reasoning: [reasoning]))).must_equal(
          [{ text: "It is sunny" }],
        )
      end
    end

    # Proves Gemini 3 accepts the thought signature riffer replays: without it
    # the second call is rejected with "Function call is missing a
    # thought_signature".
    it "replays a thought signature with a tool result" do
      cassette = "Riffer_Providers_Gemini/reasoning/_generate_text/replays_thought_signature_with_tool_result"
      VCR.use_cassette(cassette) do
        first = provider.generate_text(
          prompt: "What is the weather in Toronto?",
          model: model,
          tools: [weather_tool],
        )

        expect(first.has_tool_calls?).must_equal true
        expect(first.tool_calls.first.signature).wont_be_empty

        tool_call = first.tool_calls.first
        second = provider.generate_text(
          messages: [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            first,
            Riffer::Messages::Tool.new("Sunny, 22C", tool_call_id: tool_call.call_id, name: tool_call.name),
          ],
          model: model,
          tools: [weather_tool],
        )

        expect(second).must_be_instance_of Riffer::Messages::Assistant
        expect(second.content).wont_be_empty
        expect(second.finish_reason).must_equal :stop
      end
    end

    it "yields thought summaries when includeThoughts is set" do
      cassette = "Riffer_Providers_Gemini/reasoning/_stream_text/yields_thought_summaries"
      VCR.use_cassette(cassette) do
        events = provider.stream_text(
          prompt: "A farmer has 17 sheep and all but 9 run away. Then he buys triple the remaining. " \
                  "Compute step by step.",
          model: model,
          thinkingConfig: { includeThoughts: true },
        ).to_a
        deltas = events.grep(Riffer::StreamEvents::ReasoningDelta)
        done = events.grep(Riffer::StreamEvents::ReasoningDone)
        text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

        expect(deltas).wont_be_empty
        expect(done.size).must_equal 1
        expect(done.first.content).must_equal deltas.map(&:content).join
        expect(text_done.content).wont_include deltas.first.content
      end
    end
  end
end
