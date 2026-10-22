# frozen_string_literal: true

require "test_helper"
require "googleauth"
require "tmpdir"

describe Riffer::Providers::AnthropicVertex do
  let(:project_id) { ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project") }
  let(:access_token) { ENV.fetch("GOOGLE_CLOUD_ACCESS_TOKEN", "test_access_token") }
  let(:provider) { Riffer::Providers::AnthropicVertex.new }
  let(:model) { "claude-haiku-5-5" }

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
      expect(Riffer::Providers::AnthropicVertex.semconv_provider_name).must_equal "gcp.vertex_ai"
    end
  end

  describe ".skills_adapter" do
    it "returns XmlAdapter" do
      expect(Riffer::Providers::AnthropicVertex.skills_adapter(model)).must_equal Riffer::Skills::XmlAdapter
    end
  end

  describe "client resolution" do
    it "builds a GoogleCloud::Client from config.google_cloud" do
      Riffer.config.google_cloud.location = "europe-west4"
      client = provider.send(:client)

      expect(client).must_be_instance_of Riffer::Providers::GoogleCloud::Client
      expect(client.instance_variable_get(:@base_url)).must_equal "https://europe-west4-aiplatform.googleapis.com"
    end

    it "raises when no project id is configured" do
      Riffer.config.google_cloud.project_id = nil

      expect { provider.send(:client) }.must_raise Riffer::ArgumentError
    end

    it "uses config.google_cloud.client, shared with the google_cloud provider" do
      configured = Object.new
      Riffer.config.google_cloud.client = configured

      expect(provider.send(:client)).must_be_same_as configured
      expect(Riffer::Providers::GoogleCloud.new.send(:client)).must_be_same_as configured
    end

    it "ignores the Anthropic settings" do
      Riffer.config.anthropic.api_key = "sk-ant-secret"

      expect(provider.send(:client)).must_be_instance_of Riffer::Providers::GoogleCloud::Client
    ensure
      Riffer.config.anthropic.api_key = nil
    end
  end

  describe "model validation" do
    it "raises ArgumentError for a model with slashes" do
      expect { provider.generate_text(prompt: "Hello", model: "../admin") }.must_raise Riffer::ArgumentError
    end

    it "accepts a versioned model id" do
      expect(provider.send(:messages_path, "claude-haiku-4-5@20251001", stream: false)).
        must_equal "publishers/anthropic/models/claude-haiku-4-5@20251001:rawPredict"
    end
  end

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

    it "prices usage under the anthropic_vertex model id" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "models.json")
        catalog = { "anthropic_vertex/#{model}" => { "pricing" => { "input" => 1_000_000.0, "output" => 0.0 } } }
        File.write(path, JSON.generate({ version: 1, models: catalog }))
        Riffer.config.catalog_files = [path]
        transport.response = message_body

        expect(provider.generate_text(prompt: "Say hello", model: model).token_usage.cost).must_equal 15.0
      ensure
        Riffer.config.catalog_files = []
      end
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
      expect(request.keys).must_equal %i[anthropic_version messages max_tokens stream]
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
  end

  describe "#generate_text" do
    it "returns an Assistant message" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/_generate_text/returns_an_Assistant_message") do
        result = provider.generate_text(prompt: "Say hello", system: "Be concise", model: model)

        expect(result.content).wont_be_empty
        expect(result.finish_reason).must_equal :stop
        expect(result.token_usage).wont_be_nil
      end
    end
  end

  describe "#stream_text" do
    it "yields text, usage and finish reason events" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/_stream_text/yields_stream_events") do
        events = provider.stream_text(prompt: "Say hello", model: model).to_a

        expect(events.grep(Riffer::StreamEvents::TextDelta)).wont_be_empty
        expect(events.grep(Riffer::StreamEvents::TextDone).length).must_equal 1
        expect(events.grep(Riffer::StreamEvents::TokenUsageDone).length).must_equal 1
        expect(events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }.finish_reason).must_equal :stop
      end
    end
  end

  describe "structured output" do
    let(:params) do
      params = Riffer::Params.new
      params.required(:sentiment, String, enum: %w[positive neutral negative])
      params.required(:score, Float)
      params
    end
    let(:prompt) { "Analyze the sentiment of the following text: 'I love this product, it is amazing!'" }

    it "returns JSON matching the schema with the native strategy" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/structured_output/_generate_text/native") do
        result = provider.generate_text(
          prompt: prompt,
          model: model,
          structured_output: Riffer::Agent::StructuredOutput.new(params),
        )

        expect(result.structured_output.keys.sort).must_equal %i[score sentiment]
        expect(result.structured_output[:sentiment]).must_equal "positive"
      end
    end

    it "returns JSON matching the schema with the prompted strategy" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/structured_output/_generate_text/prompted") do
        result = provider.generate_text(
          prompt: prompt,
          model: model,
          structured_output: Riffer::Agent::StructuredOutput.new(params, strategy: :prompted),
        )

        expect(result.structured_output.keys.sort).must_equal %i[score sentiment]
        expect(result.structured_output[:sentiment]).must_equal "positive"
      end
    end

    it "streams JSON matching the schema with the native strategy" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/structured_output/_stream_text/native") do
        events = provider.stream_text(
          prompt: prompt,
          model: model,
          structured_output: Riffer::Agent::StructuredOutput.new(params),
        ).to_a
        text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

        expect(JSON.parse(text_done.content).keys.sort).must_equal %w[score sentiment]
      end
    end

    it "streams JSON matching the schema with the prompted strategy" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/structured_output/_stream_text/prompted") do
        events = provider.stream_text(
          prompt: prompt,
          model: model,
          structured_output: Riffer::Agent::StructuredOutput.new(params, strategy: :prompted),
        ).to_a
        text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
        parsed = Riffer::Agent::StructuredOutput::Parser.parse(text_done.content)

        expect(parsed.keys.sort).must_equal %i[score sentiment]
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
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/tool_calling/_generate_text/returns_tool_calls") do
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

    it "answers from the tool result in a round trip" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/tool_calling/_generate_text/tool_call_round_trip") do
        question = Riffer::Messages::User.new("What is the weather in Toronto?")
        first = provider.generate_text(messages: [question], model: model, tools: [weather_tool])
        tool_call = first.tool_calls.first
        result = Riffer::Messages::Tool.new(
          "The weather in Toronto is 15 degrees Celsius.",
          tool_call_id: tool_call.call_id,
          name: tool_call.name,
        )
        second = provider.generate_text(messages: [question, first, result], model: model, tools: [weather_tool])

        expect(second.content).must_include "15"
      end
    end

    it "streams tool call deltas and ToolCallDone" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/tool_calling/_stream_text/yields_tool_call_done") do
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
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/reasoning/_stream_text/replays_thinking_blocks") do
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

  describe "web search" do
    let(:prompt) { "What is the latest Ruby version? Answer in one sentence." }

    it "returns the cited answer from #generate_text" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/web_search/_generate_text/returns_the_cited_answer") do
        result = provider.generate_text(prompt: prompt, model: model, web_search: true)

        expect(result.content).must_include "Ruby"
        expect(result.tool_calls).must_be_empty
      end
    end

    it "accepts hash web_search options" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/web_search/_generate_text/accepts_hash_web_search_options") do
        result = provider.generate_text(prompt: prompt, model: model, web_search: { max_uses: 1 })

        expect(result.content).must_include "Ruby"
      end
    end

    it "streams the search and the cited answer" do
      VCR.use_cassette("Riffer_Providers_AnthropicVertex/web_search/_stream_text/yields_web_search_events") do
        events = provider.stream_text(prompt: prompt, model: model, web_search: true).to_a
        done = events.grep(Riffer::StreamEvents::WebSearchDone)

        expect(events.grep(Riffer::StreamEvents::WebSearchStatus)).wont_be_empty
        expect(done.first.query).wont_be_empty
        expect(done.first.sources).wont_be_empty
        expect(events.grep(Riffer::StreamEvents::ToolCallDelta)).must_be_empty
        expect(events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }.content).must_include "Ruby"
      end
    end
  end
end
