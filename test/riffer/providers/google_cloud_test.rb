# frozen_string_literal: true

require "test_helper"
require "googleauth"

describe Riffer::Providers::GoogleCloud do
  let(:project_id) { ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project") }
  let(:access_token) { ENV.fetch("GOOGLE_CLOUD_ACCESS_TOKEN", "test_access_token") }
  let(:provider) { Riffer::Providers::GoogleCloud.new }

  before do
    Riffer.config.google_cloud.project_id = project_id
    Riffer.config.google_cloud.credentials = Google::Auth::BearerTokenCredentials.new(token: access_token)
  end

  after do
    Riffer.config.google_cloud.project_id = nil
    Riffer.config.google_cloud.location = nil
    Riffer.config.google_cloud.credentials = nil
    Riffer.config.google_cloud.client = nil
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::GoogleCloud.semconv_provider_name).must_equal "gcp.vertex_ai"
    end
  end

  describe ".skills_adapter" do
    it "returns XmlAdapter for Claude models" do
      expect(Riffer::Providers::GoogleCloud.skills_adapter("claude-haiku-4-5@20251001")).
        must_equal Riffer::Skills::XmlAdapter
    end

    it "returns MarkdownAdapter for Gemini models and without a model" do
      adapters = [Riffer::Providers::GoogleCloud.skills_adapter("gemini-2.5-flash"),
                  Riffer::Providers::GoogleCloud.skills_adapter,]

      expect(adapters.uniq).must_equal [Riffer::Skills::MarkdownAdapter]
    end
  end

  describe "#initialize" do
    it "takes no arguments" do
      expect { Riffer::Providers::GoogleCloud.new(project_id: project_id) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "builds a GoogleCloud::Client from the configured project and location" do
      Riffer.config.google_cloud.location = "europe-west4"
      client = provider.send(:client)

      expect(client).must_be_instance_of Riffer::Providers::GoogleCloud::Client
      expect(client.instance_variable_get(:@location)).must_equal "europe-west4"
      expect(client.instance_variable_get(:@base_url)).must_equal "https://europe-west4-aiplatform.googleapis.com"
    end

    it "passes the configured credentials to the client" do
      credentials = Riffer.config.google_cloud.credentials

      expect(provider.send(:client).instance_variable_get(:@credentials)).must_be_same_as credentials
    end

    it "raises when no project id is configured" do
      Riffer.config.google_cloud.project_id = nil

      expect { provider.send(:client) }.must_raise Riffer::ArgumentError
    end

    it "uses the configured client" do
      configured = Object.new
      Riffer.config.google_cloud.client = configured

      expect(provider.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.google_cloud.client = -> { calls += 1 }

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "uses a subclass's build_client to bind a location" do
      eu_provider = Class.new(Riffer::Providers::GoogleCloud) do
        private

        def build_client
          Riffer::Providers::GoogleCloud::Client.new(
            project_id: Riffer.config.google_cloud.project_id, location: "eu",
            credentials: Riffer.config.google_cloud.credentials,
          )
        end
      end

      client = eu_provider.new.send(:client)

      expect(client.instance_variable_get(:@base_url)).must_equal "https://aiplatform.eu.rep.googleapis.com"
    end
  end

  describe "model validation" do
    it "raises ArgumentError for model with slashes" do
      expect { provider.generate_text(prompt: "Hello", model: "../admin") }.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError for model with spaces" do
      expect { provider.generate_text(prompt: "Hello", model: "gemini 2.5") }.must_raise Riffer::ArgumentError
    end

    it "addresses Gemini models under the google publisher" do
      expect(provider.send(:api_path, "gemini-2.5-flash-lite", "generateContent")).
        must_equal "publishers/google/models/gemini-2.5-flash-lite:generateContent"
    end

    it "accepts a versioned model id" do
      expect(provider.send(:api_path, "gemini-2.0-flash-lite@001", "generateContent")).
        must_equal "publishers/google/models/gemini-2.0-flash-lite@001:generateContent"
    end
  end

  describe "tags" do
    it "does not pass tags through to API params" do
      messages = [Riffer::Messages::User.new("Hello")]
      params = provider.send(:build_request_params, messages, "gemini-2.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.keys).must_equal %i[model contents]
    end
  end

  describe "gemini models" do
    let(:model) { "gemini-2.5-flash-lite" }

    describe "#generate_text" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/_generate_text/returns_an_Assistant_message") do
          result = provider.generate_text(prompt: "Say hello", model: model)

          expect(result).must_be_instance_of Riffer::Messages::Assistant
          expect(result.content).wont_be_empty
          expect(result.finish_reason).must_equal :stop
          expect(result.token_usage).wont_be_nil
        end
      end

      it "returns an Assistant message for system and prompt" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/_generate_text/with_system_and_prompt") do
          result = provider.generate_text(system: "Be concise", prompt: "Say hello", model: model)

          expect(result.content).wont_be_empty
        end
      end

      it "returns an Assistant message for a multi-turn conversation" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/_generate_text/with_an_Assistant_message") do
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?"),
          ]
          result = provider.generate_text(messages: messages, model: model)

          expect(result.content).wont_be_empty
        end
      end

      it "sends no tags on the wire, matching the untagged request" do
        VCR.use_cassette(
          "Riffer_Providers_GoogleCloud/gemini/_generate_text/returns_an_Assistant_message",
          record: :none,
        ) do
          result = provider.generate_text(prompt: "Say hello", model: model, tags: { "team" => "growth" })

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "structured output" do
      it "returns JSON matching the schema" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/_generate_text/structured_output") do
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: model,
            structured_output: Riffer::Agent::StructuredOutput.new(params),
          )
          parsed = JSON.parse(result.content)

          expect(parsed.keys.sort).must_equal %w[score sentiment]
          expect(result.structured_output).wont_be_nil
        end
      end
    end

    describe "#stream_text" do
      it "yields text, usage and finish reason events" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/_stream_text/yields_stream_events") do
          events = provider.stream_text(prompt: "Say hello", model: model).to_a

          expect(events.grep(Riffer::StreamEvents::TextDelta)).wont_be_empty
          expect(events.grep(Riffer::StreamEvents::TextDone).length).must_equal 1
          expect(events.grep(Riffer::StreamEvents::TokenUsageDone)).wont_be_empty
          expect(events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }.finish_reason).must_equal :stop
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

      it "returns tool calls from #generate_text" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/tool_calling/_generate_text/returns_tool_calls") do
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: model,
            tools: [weather_tool],
          )
          tool_call = result.tool_calls.first

          expect(tool_call.name).must_equal "get_weather"
          expect(JSON.parse(tool_call.arguments)["city"]).must_equal "Toronto"
          expect(result.finish_reason).must_equal :tool_calls
        end
      end

      it "answers from a Tool message in history" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/tool_calling/_generate_text/with_tool_message") do
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
          result = provider.generate_text(messages: messages, model: model, tools: [weather_tool])

          expect(result.content).must_include "15"
        end
      end

      it "yields ToolCallDone from #stream_text" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/tool_calling/_stream_text/yields_tool_call_done") do
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: model,
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(tool_done.name).must_equal "get_weather"
          expect(JSON.parse(tool_done.arguments)["city"]).must_equal "Toronto"
        end
      end
    end

    describe "file handling" do
      let(:image_base64) do
        <<~BASE64.chomp
          iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg==
        BASE64
      end

      it "describes an inline image" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/gemini/file_handling/_generate_text/with_image") do
          file = Riffer::Messages::User::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: model, files: [file])

          expect(result.content).wont_be_empty
        end
      end
    end
  end

  describe "claude models" do
    let(:model) { "claude-haiku-5-5" }

    describe "wire contract" do
      # Records requests and replays canned bodies, standing in for the HTTP transport.
      let(:transport) do
        Class.new do
          attr_reader :requests
          attr_accessor :response, :chunks

          def initialize
            @requests = []
            @chunks = []
          end

          def post(path, body)
            @requests << [path, body]
            response
          end

          def post_stream(path, body, &block)
            @requests << [path, body]
            chunks.each(&block)
          end
        end.new
      end

      before { Riffer.config.google_cloud.client = transport }

      def message_start(**usage)
        { type: "message_start", message: { id: "msg_1", role: "assistant", content: [], usage: usage } }
      end

      def sse(*events)
        events.map { |event| "event: #{event[:type]}\r\ndata: #{event.to_json}\r\n\r\n" }.join
      end

      let(:message_body) do
        {
          id: "msg_1",
          type: "message",
          role: "assistant",
          content: [
            { type: "thinking", thinking: "Hmm", signature: "sig" },
            { type: "text", text: "Hello!" },
          ],
          stop_reason: "end_turn",
          usage: { input_tokens: 10, output_tokens: 4, cache_read_input_tokens: 5 },
        }
      end

      it "posts an Anthropic Messages body to rawPredict without a model" do
        transport.response = message_body
        provider.generate_text(prompt: "Say hello", system: "Be brief", model: model, tags: { "user_id" => "u_1" })
        path, body = transport.requests.first

        expect(path).must_equal "publishers/anthropic/models/claude-haiku-5-5:rawPredict"
        expect(body).must_equal(
          anthropic_version: "vertex-2023-10-16",
          messages: [{ role: "user", content: "Say hello" }],
          max_tokens: 4096,
          system: [{ type: "text", text: "Be brief" }],
          metadata: { user_id: "u_1" },
        )
      end

      it "reads content, reasoning, usage and finish reason from the response" do
        transport.response = message_body
        result = provider.generate_text(prompt: "Say hello", model: model)

        expect(result.content).must_equal "Hello!"
        expect(result.reasoning.map(&:to_h)).must_equal [
          { type: :text, text: "Hmm", signature: "sig", format: "anthropic-messages-v1" },
        ]
        expect(result.token_usage.to_h).must_equal({ input_tokens: 15, output_tokens: 4, cache_read_tokens: 5 })
        expect([result.finish_reason, result.finish_reason_raw]).must_equal [:stop, "end_turn"]
      end

      it "prices usage under the google_cloud model id" do
        Riffer.config.pricing.set("google_cloud/#{model}", input: 1_000_000.0, output: 0.0)
        transport.response = message_body

        expect(provider.generate_text(prompt: "Say hello", model: model).token_usage.cost).must_equal 15.0
      ensure
        Riffer.config.instance_variable_set(:@pricing, Riffer::Config::Pricing.new)
      end

      it "maps tool calls back to riffer tool names" do
        tool = stub_tool("Lookup") { description "Look things up" }
        tool.identifier("crm/lookup")
        transport.response = message_body.merge(
          content: [{ type: "tool_use", id: "toolu_1", name: "crm__lookup", input: { id: 7 } }],
          stop_reason: "tool_use",
        )
        result = provider.generate_text(prompt: "Look up 7", model: model, tools: [tool])

        expect(transport.requests.first.last[:tools].first[:name]).must_equal "crm__lookup"
        expect(result.tool_calls.map(&:to_h)).must_equal [
          { call_id: "toolu_1", name: "crm/lookup", arguments: '{"id":7}' },
        ]
        expect(result.finish_reason).must_equal :tool_calls
      end

      it "streams from streamRawPredict and emits finish reason then usage after the text" do
        body = sse(
          message_start(input_tokens: 10, output_tokens: 1),
          { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
          { type: "ping" },
          { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "Hel" } },
          { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "lo" } },
          { type: "content_block_stop", index: 0 },
          { type: "message_delta", delta: { stop_reason: "end_turn" }, usage: { output_tokens: 3 } },
          { type: "message_stop" },
        )
        transport.chunks = [body[0, 50], body[50..]]
        events = provider.stream_text(prompt: "Say hello", model: model).to_a
        path, request = transport.requests.first

        expect(path).must_equal "publishers/anthropic/models/claude-haiku-5-5:streamRawPredict"
        expect(request[:stream]).must_equal true
        expect(request.key?(:model)).must_equal false
        expect(events.map { |e| e.class.name.split("::").last }).
          must_equal %w[TextDelta TextDelta TextDone FinishReasonDone TokenUsageDone]
        expect(events.last.token_usage.to_h).must_equal({ input_tokens: 10, output_tokens: 3 })
      end

      it "raises IncompleteStreamError when the stream ends without message_stop" do
        transport.chunks = [sse(
          message_start(input_tokens: 1),
          { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
          { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "Hel" } },
        )]

        expect { provider.stream_text(prompt: "Say hello", model: model).to_a }.must_raise Riffer::IncompleteStreamError
      end

      it "still routes Gemini models to generateContent" do
        transport.response = { candidates: [{ content: { parts: [{ text: "Hi" }] }, finishReason: "STOP" }] }
        result = provider.generate_text(prompt: "Say hello", model: "gemini-2.5-flash-lite")

        expect(transport.requests.first.first).
          must_equal "publishers/google/models/gemini-2.5-flash-lite:generateContent"
        expect(result.content).must_equal "Hi"
      end
    end

    describe "#generate_text" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/_generate_text/returns_an_Assistant_message") do
          result = provider.generate_text(prompt: "Say hello", system: "Be concise", model: model)

          expect(result.content).wont_be_empty
          expect(result.finish_reason).must_equal :stop
          expect(result.token_usage).wont_be_nil
        end
      end
    end

    # Disabled until the org policy constraints/vertexai.allowedPartnerModelFeatures allows
    # publishers/anthropic/models/claude-haiku-5-5:structured_outputs on the recording project.
    # describe "structured output" do
    #   it "returns JSON matching the schema" do
    #     VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/_generate_text/structured_output") do
    #       params = Riffer::Params.new
    #       params.required(:sentiment, String)
    #       params.required(:score, Float)
    #       result = provider.generate_text(
    #         prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
    #         model: model,
    #         structured_output: Riffer::Agent::StructuredOutput.new(params),
    #       )

    #       expect(JSON.parse(result.content).keys.sort).must_equal %w[score sentiment]
    #     end
    #   end
    # end

    describe "#stream_text" do
      it "yields text, usage and finish reason events" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/_stream_text/yields_stream_events") do
          events = provider.stream_text(prompt: "Say hello", model: model).to_a

          expect(events.grep(Riffer::StreamEvents::TextDelta)).wont_be_empty
          expect(events.grep(Riffer::StreamEvents::TextDone).length).must_equal 1
          expect(events.grep(Riffer::StreamEvents::TokenUsageDone).length).must_equal 1
          expect(events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }.finish_reason).must_equal :stop
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

      it "returns tool calls from #generate_text" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/tool_calling/_generate_text/returns_tool_calls") do
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: model,
            tools: [weather_tool],
          )
          tool_call = result.tool_calls.first

          expect(tool_call.name).must_equal "get_weather"
          expect(JSON.parse(tool_call.arguments)["city"]).must_equal "Toronto"
          expect(result.finish_reason).must_equal :tool_calls
        end
      end

      it "streams tool call deltas and ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/tool_calling/_stream_text/yields_tool_call_done") do
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: model,
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(events.grep(Riffer::StreamEvents::ToolCallDelta)).wont_be_empty
          expect(tool_done.name).must_equal "get_weather"
          expect(JSON.parse(tool_done.arguments)["city"]).must_equal "Toronto"
        end
      end
    end

    describe "reasoning" do
      let(:thinking_options) do
        {
          model: model,
          max_tokens: 4096,
          thinking: { type: "adaptive", display: "summarized" },
          output_config: { effort: "high" },
        }
      end

      it "sends turn one's streamed reasoning back and gets an answer" do
        VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/reasoning/_stream_text/replays_thinking_blocks") do
          # Adaptive thinking skips trivial prompts, so this one needs a few steps.
          question = Riffer::Messages::User.new(
            "A bat and a ball cost 1.10 in total. The bat costs 1.00 more than the ball. " \
            "What is 17 times the ball price plus 23 times the bat price? Reply with just the number.",
          )

          first = provider.stream_text(messages: [question], **thinking_options).to_a
          parts = first.grep(Riffer::StreamEvents::ReasoningDone).map(&:part)
          answer = first.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }.content

          expect(first.grep(Riffer::StreamEvents::ReasoningDelta)).wont_be_empty
          expect(parts.first.signature).wont_be_nil

          history = [
            question,
            Riffer::Messages::Assistant.new(answer, reasoning: parts),
            Riffer::Messages::User.new("Now add 10. Reply with just the number."),
          ]
          second = provider.generate_text(messages: history, **thinking_options)

          expect(second.content).must_include "35"
        end
      end
    end

    # Disabled until the org policy constraints/vertexai.allowedPartnerModelFeatures allows
    # publishers/anthropic/models/claude-haiku-5-5:web_search on the recording project.
    # describe "web search" do
    #   it "reports the search and keeps the cited text" do
    #     VCR.use_cassette("Riffer_Providers_GoogleCloud/claude/web_search/_stream_text/yields_web_search_events") do
    #       events = provider.stream_text(
    #         prompt: "What is the latest Ruby version?",
    #         model: model,
    #         web_search: true,
    #       ).to_a

    #       expect(events.grep(Riffer::StreamEvents::WebSearchStatus)).wont_be_empty
    #       expect(events.grep(Riffer::StreamEvents::WebSearchDone)).wont_be_empty
    #       expect(events.grep(Riffer::StreamEvents::ToolCallDelta)).must_be_empty
    #       expect(events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }.content).wont_be_empty
    #     end
    #   end
    # end
  end
end
