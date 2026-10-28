# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Gemini do
  let(:api_key) { ENV.fetch("GEMINI_API_KEY", "test_api_key") }

  before { Riffer.config.gemini.api_key = api_key }

  after do
    Riffer.config.gemini.api_key = nil
    Riffer.config.gemini.client = nil
    Riffer.config.gemini.base_url = nil
  end

  def with_env(vars)
    original = vars.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
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

    it "falls back to GEMINI_API_KEY when no api_key is configured" do
      Riffer.config.gemini.api_key = nil
      stub = stub_request(:post, /generativelanguage\.googleapis\.com/).
        with(headers: { "x-goog-api-key" => "env_key" }).
        to_return(status: 200, body: "{}")

      with_env("GEMINI_API_KEY" => "env_key") do
        Riffer::Providers::Gemini.new.send(:client).post("v1beta/x", {})
      end

      assert_requested stub
    end

    it "prefers the configured api_key over GEMINI_API_KEY" do
      Riffer.config.gemini.api_key = "config_key"
      stub = stub_request(:post, /generativelanguage\.googleapis\.com/).
        with(headers: { "x-goog-api-key" => "config_key" }).
        to_return(status: 200, body: "{}")

      with_env("GEMINI_API_KEY" => "env_key") do
        Riffer::Providers::Gemini.new.send(:client).post("v1beta/x", {})
      end

      assert_requested stub
    end

    it "uses the configured base_url" do
      Riffer.config.gemini.base_url = "http://localhost:8080"
      stub = stub_request(:post, "http://localhost:8080/v1beta/x").to_return(status: 200, body: "{}")

      Riffer::Providers::Gemini.new.send(:client).post("v1beta/x", {})

      assert_requested stub
    end

    it "raises naming both settings when no api_key is available" do
      Riffer.config.gemini.api_key = nil

      error = with_env("GEMINI_API_KEY" => nil) do
        expect { Riffer::Providers::Gemini.new.send(:client) }.must_raise Riffer::ArgumentError
      end

      expect(error.message).must_include "config.gemini.api_key"
      expect(error.message).must_include "GEMINI_API_KEY"
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
      path = provider.send(:api_path, "gemini-3.5-flash-lite", "generateContent")

      expect(path).must_include "v1beta/models/gemini-3.5-flash-lite:generateContent"
    end
  end

  describe "structured output" do
    it "sends the strict JSON schema in responseFormat" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:result, Riffer::Params::AnyOf) do
        variant { required :name, String }
        variant { required :error_code, String }
      end
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result[:generationConfig]).must_equal(
        responseFormat: {
          text: { mimeType: "APPLICATION_JSON", schema: structured_output.json_schema(strict: true) },
        },
      )
    end

    it "makes optional fields required and nullable" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:name, String)
      params.optional(:postal_code, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Extract")]

      schema = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { structured_output: structured_output },
      ).dig(:generationConfig, :responseFormat, :text, :schema)

      expect(schema[:required]).must_equal %w[name postal_code]
      expect(schema.dig(:properties, "postal_code", :type)).must_equal %w[string null]
    end

    it "raises for a Hash param without a block" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:address, Hash)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Extract")]
      options = { structured_output: structured_output }

      expect do
        provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", options)
      end.must_raise Riffer::ArgumentError
    end

    it "does not include generationConfig when not configured" do
      provider = Riffer::Providers::Gemini.new
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", {})

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
        "gemini-3.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result.key?(:structured_output)).must_equal false
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::Gemini.new }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }

    it "does not add a labels field (the Developer API has none)" do
      params = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.key?(:labels)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end

    it "never leaks tags into generationConfig" do
      params = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { temperature: 0.5, tags: { "team" => "growth" } },
      )

      expect(params[:generationConfig].key?(:tags)).must_equal false
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

    it "declares tool parameters as JSON Schema" do
      provider = Riffer::Providers::Gemini.new
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tools: [weather_tool] })

      expect(result[:tools]).must_equal [{
        functionDeclarations: [{
          name: weather_tool.name,
          description: weather_tool.description,
          parametersJsonSchema: weather_tool.parameters_schema,
        }],
      }]
    end

    describe "thought signatures" do
      let(:provider) { Riffer::Providers::Gemini.new }
      let(:format) { Riffer::Providers::Gemini::REASONING_FORMAT }
      let(:signed_response) do
        toronto = { id: "call_1", name: "get_weather", args: { city: "Toronto" } }
        paris = { id: "call_2", name: "get_weather", args: { city: "Paris" } }
        parts = [
          { text: "Checking.", thoughtSignature: "text-sig" },
          { functionCall: toronto, thoughtSignature: "call-sig" },
          { functionCall: paris },
        ]
        { candidates: [{ content: { parts: parts } }] }
      end

      def tool_result(tool_call)
        Riffer::Messages::Tool.new(
          "15 degrees Celsius and sunny.",
          tool_call_id: tool_call.call_id,
          name: tool_call.name,
        )
      end

      it "keeps each signature as an encrypted part tied to its tool call" do
        tool_calls = provider.send(:extract_tool_calls, signed_response)
        parts = provider.send(:extract_reasoning, signed_response)

        expect(parts.map(&:to_h)).must_equal [
          { type: :encrypted, data: "text-sig", format: format },
          { type: :encrypted, data: "call-sig", id: tool_calls.first.call_id, format: format },
        ]
      end

      it "makes its own call ids and keeps Gemini's on the end" do
        call_ids = provider.send(:extract_tool_calls, signed_response).map(&:call_id)

        expect(call_ids[0]).must_match(/\Agemini_call_\h{24}_call_1\z/)
        expect(call_ids[1]).must_match(/\Agemini_call_\h{24}_call_2\z/)
      end

      it "makes its own call id when Gemini sends none" do
        response = { candidates: [{ content: { parts: [{ functionCall: { name: "get_weather", args: {} } }] } }] }

        call_id = provider.send(:extract_tool_calls, response).first.call_id

        expect(call_id).must_match(/\Agemini_call_\h{24}\z/)
      end

      it "sends Gemini's call id back on each function response" do
        tool_calls = provider.send(:extract_tool_calls, signed_response)

        contents = provider.send(:partition_messages, tool_calls.map { |tc| tool_result(tc) })[:contents]

        expect(contents.size).must_equal 1
        expect(contents.first[:parts].map { |part| part[:functionResponse][:id] }).must_equal %w[call_1 call_2]
      end

      it "sends no call id for tool calls riffer did not get from Gemini" do
        tool_call = Riffer::Messages::Assistant::ToolCall.new(
          call_id: "toolu_123",
          name: "get_weather",
          arguments: "{}",
        )
        message = Riffer::Messages::Assistant.new("", tool_calls: [tool_call])

        contents = provider.send(:partition_messages, [message, tool_result(tool_call)])[:contents]

        expect(contents[0][:parts].first[:functionCall]).wont_include :id
        expect(contents[1][:parts].first[:functionResponse]).wont_include :id
      end

      it "signs the first call of a step Gemini did not sign with the placeholder" do
        tool_calls = %w[Toronto Paris].each_with_index.map do |city, index|
          Riffer::Messages::Assistant::ToolCall.new(
            call_id: "toolu_#{index}",
            name: "get_weather",
            arguments: { city: city }.to_json,
          )
        end
        message = Riffer::Messages::Assistant.new("", tool_calls: tool_calls)

        result = provider.send(:convert_assistant_to_gemini_format, message)

        expect(result[:parts].map { |part| part[:thoughtSignature] }).must_equal(
          [Riffer::Providers::Gemini::PLACEHOLDER_SIGNATURE, nil],
        )
      end

      it "puts each signature back on the part it came on and skips other formats" do
        foreign = Riffer::Messages::Assistant::ReasoningPart.new(
          type: :encrypted,
          data: "foreign",
          format: "anthropic-messages-v1",
        )
        message = Riffer::Messages::Assistant.new(
          "Checking.",
          tool_calls: provider.send(:extract_tool_calls, signed_response),
          reasoning: provider.send(:extract_reasoning, signed_response) + [foreign],
        )

        result = provider.send(:convert_assistant_to_gemini_format, message)

        expect(result[:parts]).must_equal [
          { text: "Checking.", thoughtSignature: "text-sig" },
          {
            functionCall: { id: "call_1", name: "get_weather", args: { "city" => "Toronto" } },
            thoughtSignature: "call-sig",
          },
          { functionCall: { id: "call_2", name: "get_weather", args: { "city" => "Paris" } } },
        ]
      end
    end
  end

  describe "web search" do
    let(:provider) { Riffer::Providers::Gemini.new }
    let(:model) { "gemini-3.5-flash-lite" }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }
    let(:weather_tool) do
      stub_tool("GetWeather") do
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    it "sends the googleSearch tool with server-side invocations on" do
      result = provider.send(:build_request_params, messages, model, { web_search: true })

      expect(result[:tools]).must_equal [{ googleSearch: {} }]
      expect(result[:toolConfig]).must_equal({ includeServerSideToolInvocations: true })
      expect(result).wont_include :generationConfig
    end

    it "merges a web_search hash into the googleSearch tool" do
      time_range = { startTime: "2026-01-01T00:00:00Z", endTime: "2026-10-22T00:00:00Z" }

      result = provider.send(:build_request_params, messages, model, { web_search: { timeRangeFilter: time_range } })

      expect(result[:tools]).must_equal [{ googleSearch: { timeRangeFilter: time_range } }]
    end

    it "sends googleSearch after the function declarations" do
      result = provider.send(:build_request_params, messages, model, { tools: [weather_tool], web_search: true })

      expect(result[:tools].map(&:keys)).must_equal [[:functionDeclarations], [:googleSearch]]
    end

    it "leaves out the signatures of search toolCall and toolResponse parts" do
      search = { toolType: "GOOGLE_SEARCH_WEB", id: "call_1" }
      parts = [
        { toolCall: search.merge(args: { queries: ["ruby"] }), thoughtSignature: "call-sig" },
        { toolResponse: search.merge(response: {}), thoughtSignature: "response-sig" },
        { text: "Ruby 4.0.", thoughtSignature: "text-sig" },
      ]
      response = { candidates: [{ content: { parts: parts } }] }

      expect(provider.send(:extract_reasoning, response).map(&:data)).must_equal ["text-sig"]
    end

    it "streams no reasoning for search toolCall and toolResponse parts" do
      search = { toolType: "GOOGLE_SEARCH_WEB", id: "call_1" }
      parts = [
        { toolCall: search.merge(args: { queries: ["ruby"] }), thoughtSignature: "call-sig" },
        { toolResponse: search.merge(response: {}), thoughtSignature: "response-sig" },
        { text: "Ruby 4.0.", thoughtSignature: "text-sig" },
      ]
      chunks = parts.map { |part| "data: #{{ candidates: [{ content: { parts: [part] } }] }.to_json}\n\n" }
      client = Object.new
      client.define_singleton_method(:post_stream) { |_path, _body, &block| chunks.each(&block) }
      Riffer.config.gemini.client = client

      events = provider.stream_text(prompt: "Ruby?", model: model, web_search: true).to_a

      expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |event| event.part.data }).must_equal ["text-sig"]
    end
  end

  describe "reasoning level" do
    let(:provider) { Riffer::Providers::Gemini.new }

    it "passes every level through as the thinking level" do
      Riffer::Agent::Config::REASONING_LEVELS.each do |level|
        expect(provider.send(:default_reasoning_options, level)).must_equal(
          { thinkingConfig: { thinkingLevel: level.to_s } },
        )
      end
    end

    describe "with a catalog entry" do
      before { Riffer.config.catalog_files = [REASONING_CATALOG_PATH] }
      after { Riffer.config.catalog_files = [] }

      it "sends the catalog's thinking budget instead of a thinking level" do
        client = Object.new
        client.define_singleton_method(:post) do |path, body|
          @request = [path, body]
          { candidates: [{ content: { parts: [{ text: "391" }] }, finishReason: "STOP" }] }
        end
        Riffer.config.gemini.client = client

        provider.generate_text(prompt: "17 * 23?", model: "gemini-2.5-flash-lite", riffer_reasoning_level: :low)
        path, body = client.instance_variable_get(:@request)

        expect(path).must_equal "v1beta/models/gemini-2.5-flash-lite:generateContent"
        expect(body[:generationConfig]).must_equal({ thinkingConfig: { thinkingBudget: 1024 } })
      end
    end
  end

  describe "usage" do
    it "streams one TokenUsageDone with the final counts" do
      chunks = [[2, "Hello"], [20, " there"]].map do |count, text|
        chunk = {
          candidates: [{ content: { parts: [{ text: text }] } }],
          usageMetadata: { promptTokenCount: 14, candidatesTokenCount: count },
        }
        "data: #{chunk.to_json}\n\n"
      end
      client = Object.new
      client.define_singleton_method(:post_stream) { |_path, _body, &block| chunks.each(&block) }
      Riffer.config.gemini.client = client

      events = Riffer::Providers::Gemini.new.stream_text(prompt: "Hi", model: "gemini-3.5-flash-lite").to_a
      usage = events.grep(Riffer::StreamEvents::TokenUsageDone)

      expect(usage.size).must_equal 1
      expect([usage.first.token_usage.input_tokens, usage.first.token_usage.output_tokens]).must_equal [14, 20]
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
end
