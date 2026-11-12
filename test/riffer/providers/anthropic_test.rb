# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Anthropic do
  let(:api_key) { ENV.fetch("ANTHROPIC_API_KEY", "test_api_key") }

  before { Riffer.config.anthropic.api_key = api_key }

  after do
    Riffer.config.anthropic.api_key = nil
    Riffer.config.anthropic.base_url = nil
    Riffer.config.anthropic.client = nil
  end

  def with_env(vars)
    original = vars.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end

  def block_start(index, block) = { type: "content_block_start", index: index, content_block: block }
  def delta(index, delta) = { type: "content_block_delta", index: index, delta: delta }
  def block_stop(index) = { type: "content_block_stop", index: index }

  # Streams +events+ between a message_start and a message_stop through +provider+.
  def stream_events(events)
    events = [
      { type: "message_start", message: { id: "msg_1", role: "assistant", content: [], usage: { input_tokens: 1 } } },
      *events,
      { type: "message_delta", delta: { stop_reason: "end_turn" }, usage: { output_tokens: 1 } },
      { type: "message_stop" },
    ]
    sse = events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join
    client = Object.new
    client.define_singleton_method(:post_stream) { |_path, _body, &block| block.call(sse) }
    provider.instance_variable_set(:@client, client)
    provider.stream_text(prompt: "Hi", model: model).to_a
  end

  describe ".skills_adapter" do
    it "returns XmlAdapter without a model" do
      expect(Riffer::Providers::Anthropic.skills_adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns XmlAdapter regardless of the model" do
      expect(Riffer::Providers::Anthropic.skills_adapter("claude-sonnet-4-6")).must_equal Riffer::Skills::XmlAdapter
    end
  end

  describe ".supports_deferred_tools?" do
    it "returns true" do
      expect(Riffer::Providers::Anthropic.supports_deferred_tools?).must_equal true
    end

    it "lets an agent defer tools" do
      loader = stub_tool("FindTools") { description "Find more tools" }
      deferred = stub_tool("ListEvents") { description "List calendar events" }
      agent_class = Class.new(Riffer::Agent) do
        model "anthropic/claude-haiku-5-5"
        uses_tools [loader]
        deferred_tools [deferred]
      end

      expect(agent_class.new.deferred_tools).must_equal [deferred]
    end
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::Anthropic.semconv_provider_name).must_equal "anthropic"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::Anthropic.new }

    it "normalizes end_turn to stop" do
      expect(provider.send(:extract_finish_reason, { stop_reason: "end_turn" }).reason).must_equal :stop
    end

    it "normalizes stop_sequence to stop" do
      expect(provider.send(:extract_finish_reason, { stop_reason: "stop_sequence" }).reason).must_equal :stop
    end

    it "normalizes max_tokens to length" do
      expect(provider.send(:extract_finish_reason, { stop_reason: "max_tokens" }).reason).must_equal :length
    end

    it "normalizes tool_use to tool_calls" do
      expect(provider.send(:extract_finish_reason, { stop_reason: "tool_use" }).reason).must_equal :tool_calls
    end

    it "normalizes refusal to content_filter" do
      expect(provider.send(:extract_finish_reason, { stop_reason: "refusal" }).reason).must_equal :content_filter
    end

    it "normalizes model_context_window_exceeded to context_window" do
      finish_reason = provider.send(:extract_finish_reason, { stop_reason: "model_context_window_exceeded" })

      expect(finish_reason.reason).must_equal :context_window
    end

    it "normalizes pause_turn to other and keeps the raw value" do
      finish_reason = provider.send(:extract_finish_reason, { stop_reason: "pause_turn" })

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "pause_turn"]
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:extract_finish_reason, { stop_reason: "mystery" })

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "mystery"]
    end

    it "returns nil without a stop reason" do
      expect(provider.send(:extract_finish_reason, {})).must_be_nil
    end
  end

  describe "#initialize" do
    it "creates the provider" do
      provider = Riffer::Providers::Anthropic.new

      expect(provider).must_be_instance_of Riffer::Providers::Anthropic
    end

    it "takes no arguments" do
      expect { Riffer::Providers::Anthropic.new(api_key: api_key) }.must_raise ArgumentError
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::Anthropic.new(timeout: 60) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "uses the configured client" do
      configured = Object.new
      Riffer.config.anthropic.client = configured

      expect(Riffer::Providers::Anthropic.new.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.anthropic.client = -> { calls += 1 }
      provider = Riffer::Providers::Anthropic.new

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      provider = Riffer::Providers::Anthropic.new

      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "prefers a configured client over configured credentials" do
      configured = Object.new
      Riffer.config.anthropic.client = configured

      expect(Riffer::Providers::Anthropic.new.send(:client)).must_be_same_as configured
    end

    it "builds a client from ANTHROPIC_API_KEY" do
      Riffer.config.anthropic.api_key = nil
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages").
        with(headers: { "authorization" => "Bearer env_key" }).
        to_return(status: 200, body: "{}")

      with_env("ANTHROPIC_API_KEY" => "env_key", "ANTHROPIC_BASE_URL" => nil) do
        Riffer::Providers::Anthropic.new.send(:client).post("v1/messages", {})
      end

      assert_requested stub
    end

    it "prefers the configured api_key over ANTHROPIC_API_KEY" do
      Riffer.config.anthropic.api_key = "config_key"
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages").
        with(headers: { "authorization" => "Bearer config_key" }).
        to_return(status: 200, body: "{}")

      with_env("ANTHROPIC_API_KEY" => "env_key", "ANTHROPIC_BASE_URL" => nil) do
        Riffer::Providers::Anthropic.new.send(:client).post("v1/messages", {})
      end

      assert_requested stub
    end

    it "builds a client from ANTHROPIC_BASE_URL" do
      stub = stub_request(:post, "http://localhost:8080/v1/messages").to_return(status: 200, body: "{}")

      with_env("ANTHROPIC_BASE_URL" => "http://localhost:8080") do
        Riffer::Providers::Anthropic.new.send(:client).post("v1/messages", {})
      end

      assert_requested stub
    end

    it "prefers the configured base_url over ANTHROPIC_BASE_URL" do
      Riffer.config.anthropic.base_url = "http://localhost:8080/"
      stub = stub_request(:post, "http://localhost:8080/v1/messages").to_return(status: 200, body: "{}")

      with_env("ANTHROPIC_BASE_URL" => "http://env.example.test") do
        Riffer::Providers::Anthropic.new.send(:client).post("v1/messages", {})
      end

      assert_requested stub
    end

    it "raises naming both settings when no API key is set" do
      Riffer.config.anthropic.api_key = nil

      error = with_env("ANTHROPIC_API_KEY" => nil) do
        expect { Riffer::Providers::Anthropic.new.send(:client) }.must_raise Riffer::ArgumentError
      end

      expect(error.message).must_include "config.anthropic.api_key"
      expect(error.message).must_include "ANTHROPIC_API_KEY"
    end

    describe "with an anthropic gem client configured" do
      # The gem is not in the bundle, so a stand-in plays its client class.
      before { Object.const_set(:Anthropic, Module.new.tap { |sdk| sdk.const_set(:Client, Class.new) }) }
      after { Object.send(:remove_const, :Anthropic) }

      it "raises a migration error" do
        Riffer.config.anthropic.client = Anthropic::Client.new
        error = expect { Riffer::Providers::Anthropic.new.send(:client) }.must_raise Riffer::ArgumentError

        expect(error.message).must_include "Riffer::Providers::Anthropic::Client"
      end

      it "raises a migration error for a client returned by a Proc" do
        Riffer.config.anthropic.client = -> { Anthropic::Client.new }

        expect { Riffer::Providers::Anthropic.new.send(:client) }.must_raise Riffer::ArgumentError
      end
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::Anthropic.new }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }
    let(:model) { "claude-haiku-4-5-20251001" }

    it "maps only the reserved user_id to metadata.user_id, dropping all other tags" do
      params = provider.send(
        :build_request_params,
        messages,
        model,
        { tags: { "user_id" => "u_1", "team" => "growth" } },
      )

      expect(params[:metadata]).must_equal({ user_id: "u_1" })
    end

    it "omits metadata when no user_id tag is present" do
      params = provider.send(:build_request_params, messages, model, { tags: { "team" => "growth" } })

      expect(params.key?(:metadata)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, model, { tags: { "user_id" => "u_1" } })

      expect(params.key?(:tags)).must_equal false
    end
  end

  describe "structured output" do
    it "includes output_config.format in request params" do
      provider = Riffer::Providers::Anthropic.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      params.required(:score, :number)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "claude-haiku-4-5-20251001",
        { structured_output: structured_output },
      )

      expect(params[:output_config][:format][:type]).must_equal "json_schema"
    end

    it "includes json_schema in format" do
      provider = Riffer::Providers::Anthropic.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "claude-haiku-4-5-20251001",
        { structured_output: structured_output },
      )

      expect(params[:output_config][:format][:schema][:type]).must_equal "object"
    end

    it "does not include output_config when not configured" do
      provider = Riffer::Providers::Anthropic.new
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "claude-haiku-4-5-20251001", {})

      expect(params.key?(:output_config)).must_equal false
    end

    it "preserves caller-supplied output_config keys alongside format" do
      provider = Riffer::Providers::Anthropic.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "claude-haiku-4-5-20251001",
        { structured_output: structured_output, output_config: { effort: "high" } },
      )

      expect(params[:output_config][:effort]).must_equal "high"
      expect(params[:output_config][:format][:type]).must_equal "json_schema"
    end

    it "overrides a caller-supplied format with the structured output format" do
      provider = Riffer::Providers::Anthropic.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "claude-haiku-4-5-20251001",
        { structured_output: structured_output, output_config: { effort: "low", format: { type: "text" } } },
      )

      expect(params[:output_config][:format][:type]).must_equal "json_schema"
      expect(params[:output_config][:effort]).must_equal "low"
    end

    it "passes caller-supplied output_config through unchanged without structured output" do
      provider = Riffer::Providers::Anthropic.new
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(
        :build_request_params,
        messages,
        "claude-haiku-4-5-20251001",
        { output_config: { effort: "high" } },
      )

      expect(params[:output_config]).must_equal({ effort: "high" })
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::Anthropic.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "claude-haiku-4-5-20251001",
        { structured_output: structured_output },
      )

      expect(params.key?(:structured_output)).must_equal false
    end
  end

  describe "web search" do
    let(:provider) { Riffer::Providers::Anthropic.new }
    let(:model) { "claude-haiku-5-5" }

    def search_events(index)
      [
        block_start(index, { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: {} }),
        delta(index, { type: "input_json_delta", partial_json: '{"query":"ruby"}' }),
        block_stop(index),
        block_start(
          index + 1,
          { type: "web_search_tool_result", tool_use_id: "srvtoolu_1",
            content: [{ type: "web_search_result", title: "Ruby", url: "https://ruby-lang.org" }], },
        ),
        block_stop(index + 1),
      ]
    end

    it "streams the search query on WebSearchStatus" do
      events = stream_events(search_events(0))

      expect(events.grep(Riffer::StreamEvents::WebSearchStatus).map(&:query)).must_equal ["ruby"]
      expect(events.grep(Riffer::StreamEvents::WebSearchDone).map(&:query)).must_equal ["ruby"]
    end

    it "streams no ToolCallDelta for the search input" do
      events = stream_events(search_events(0))

      expect(events.grep(Riffer::StreamEvents::ToolCallDelta)).must_be_empty
      expect(events.grep(Riffer::StreamEvents::ToolCallDone)).must_be_empty
    end
  end

  describe "pause_turn" do
    let(:provider) { Riffer::Providers::Anthropic.new }
    let(:model) { "claude-haiku-4-5-20251001" }

    def text_block(text) = { type: "text", text: text }
    def search_call_block(id) = { type: "server_tool_use", id: id, name: "web_search", input: { query: "ruby" } }
    def search_result_block(id) = { type: "web_search_tool_result", tool_use_id: id, content: [] }

    def segment(content, stop_reason, usage: { input_tokens: 10, output_tokens: 5 })
      { content: content, stop_reason: stop_reason, usage: usage }
    end

    def sse_body(segment)
      events = [
        {
          type: "message_start",
          message: {
            role: "assistant", content: [], usage: segment[:usage].merge(output_tokens: 1), **segment.slice(:container),
          },
        },
        *segment[:content].each_with_index.flat_map { |block, index| block_events(index, block) },
        {
          type: "message_delta",
          delta: { stop_reason: segment[:stop_reason], **segment.slice(:container) },
          usage: { output_tokens: segment[:usage][:output_tokens] },
        },
        { type: "message_stop" },
      ]
      events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join
    end

    def block_events(index, block)
      start, delta = case block[:type]
                     when "text" then [block.merge(text: ""), { type: "text_delta", text: block[:text] }]
                     when "server_tool_use"
                       [block.merge(input: {}), { type: "input_json_delta", partial_json: block[:input].to_json }]
                     else [block, nil]
                     end
      [
        { type: "content_block_start", index: index, content_block: start },
        *(delta ? [{ type: "content_block_delta", index: index, delta: delta }] : []),
        { type: "content_block_stop", index: index },
      ]
    end

    def stub_messages(bodies)
      requests = []
      stub_request(:post, "https://api.anthropic.com/v1/messages").to_return do |request|
        requests << JSON.parse(request.body, symbolize_names: true)
        { status: 200, body: bodies.shift }
      end
      requests
    end

    def parts_of(content)
      provider.send(:extract_parts, { content: content })
    end

    let(:paused) do
      content = [text_block("Let me search."), search_call_block("srvtoolu_1"), search_result_block("srvtoolu_1")]
      segment(content, "pause_turn")
    end
    let(:finished) do
      content = [search_call_block("srvtoolu_2"), search_result_block("srvtoolu_2"), text_block("Ruby 4.0.")]
      segment(content, "end_turn", usage: { input_tokens: 30, output_tokens: 7 })
    end
    let(:resumed) { { role: "assistant", content: paused[:content] } }
    let(:container) { { id: "container_1", expires_at: "2026-11-03T18:00:00Z" } }
    let(:unanswered) do
      segment([text_block("Searching."), search_call_block("srvtoolu_1")], "pause_turn")
    end
    let(:answered) do
      segment([search_result_block("srvtoolu_1"), text_block("Found it.")], "end_turn")
    end
    let(:cut_off) { segment([text_block("Let me"), search_call_block("srvtoolu_1")], "max_tokens") }

    describe "#generate_text" do
      it "continues the turn with the paused content as the last message, otherwise unchanged" do
        requests = stub_messages([paused.to_json, finished.to_json])

        provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(requests.size).must_equal 2
        expect(requests[1].except(:messages)).must_equal requests[0].except(:messages)
        expect(requests[1][:messages]).must_equal [*requests[0][:messages], resumed]
      end

      it "returns one turn with every segment's parts, the summed usage and the final finish reason" do
        stub_messages([paused.to_json, finished.to_json])

        result = provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(result.parts.map(&:to_h)).must_equal parts_of(paused[:content] + finished[:content]).map(&:to_h)
        expect(result.content).must_equal "Let me search.Ruby 4.0."
        expect(result.token_usage.to_h).must_equal({ input_tokens: 40, output_tokens: 12 })
        expect([result.finish_reason, result.finish_reason_raw]).must_equal [:stop, "end_turn"]
      end

      it "sends the paused response's container id with the continuation" do
        requests = stub_messages([paused.merge(container: container).to_json, finished.to_json])

        provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(requests.map { |request| request[:container] }).must_equal [nil, "container_1"]
      end

      it "sends no container when the paused response has none" do
        requests = stub_messages([paused.to_json, finished.to_json])

        provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(requests[1]).wont_include :container
      end

      it "resends an unanswered server_tool_use as it came" do
        requests = stub_messages([unanswered.to_json, answered.to_json])

        result = provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(requests[1][:messages].last).must_equal({ role: "assistant", content: unanswered[:content] })
        expect(result.parts.grep(Riffer::Messages::Assistant::ServerToolPart).map { |part| [part.id, part.kind] }).
          must_equal [["srvtoolu_1", :call], ["srvtoolu_1", :result]]
      end

      it "stops after 8 continuations and finishes with other" do
        requests = stub_messages([paused.to_json] * 10)

        result = provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(requests.size).must_equal 9
        expect(requests.last[:messages].last[:content]).must_equal paused[:content] * 8
        expect(result.parts.size).must_equal paused[:content].size * 9
        expect([result.finish_reason, result.finish_reason_raw]).must_equal [:other, "pause_turn"]
      end

      it "does not continue a turn cut off by max_tokens" do
        requests = stub_messages([cut_off.to_json])

        result = provider.generate_text(prompt: "Latest Ruby?", model: model, web_search: true)

        expect(requests.size).must_equal 1
        expect(result.finish_reason).must_equal :length
      end
    end

    describe "#stream_text" do
      it "continues the turn with the paused content as the last message, otherwise unchanged" do
        requests = stub_messages([sse_body(paused), sse_body(finished)])

        provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a

        expect(requests.size).must_equal 2
        expect(requests[1].except(:messages)).must_equal requests[0].except(:messages)
        expect(requests[1][:messages]).must_equal [*requests[0][:messages], resumed]
      end

      it "yields one TextDone, FinishReasonDone and TokenUsageDone for the whole turn" do
        stub_messages([sse_body(paused), sse_body(finished)])

        events = provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a
        done_events = events.grep(Riffer::StreamEvents::TextDone) +
                      events.grep(Riffer::StreamEvents::FinishReasonDone) +
                      events.grep(Riffer::StreamEvents::TokenUsageDone)

        expect(events.last(3)).must_equal done_events
        expect(done_events[0].content).must_equal "Let me search.Ruby 4.0."
        expect([done_events[1].finish_reason, done_events[1].raw_finish_reason]).must_equal [:stop, "end_turn"]
        expect(done_events[2].token_usage.to_h).must_equal({ input_tokens: 40, output_tokens: 12 })
      end

      it "sends the paused response's container id with the continuation" do
        requests = stub_messages([sse_body(paused.merge(container: container)), sse_body(finished)])

        provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a

        expect(requests.map { |request| request[:container] }).must_equal [nil, "container_1"]
      end

      it "sends no container when the paused response has none" do
        requests = stub_messages([sse_body(paused), sse_body(finished)])

        provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a

        expect(requests[1]).wont_include :container
      end

      it "resends an unanswered server_tool_use as it came" do
        requests = stub_messages([sse_body(unanswered), sse_body(answered)])

        provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a

        expect(requests[1][:messages].last).must_equal({ role: "assistant", content: unanswered[:content] })
      end

      it "stops after 8 continuations and finishes with other" do
        requests = stub_messages([sse_body(paused)] * 10)

        events = provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a

        expect(requests.size).must_equal 9
        expect(requests.last[:messages].last[:content]).must_equal paused[:content] * 8
        expect(events.grep(Riffer::StreamEvents::FinishReasonDone).map(&:raw_finish_reason)).must_equal ["pause_turn"]
      end

      it "does not continue a turn cut off by max_tokens" do
        requests = stub_messages([sse_body(cut_off)])

        events = provider.stream_text(prompt: "Latest Ruby?", model: model, web_search: true).to_a

        expect(requests.size).must_equal 1
        expect(events.grep(Riffer::StreamEvents::FinishReasonDone).map(&:finish_reason)).must_equal [:length]
      end

      it "gives an agent the same parts as generate_text" do
        stub_messages([paused.to_json, finished.to_json, sse_body(paused), sse_body(finished)])
        agent_class = stub_agent("PauseTurnAgent") do
          model "anthropic/claude-haiku-4-5-20251001"
          model_options web_search: true
        end
        generated = agent_class.new
        streamed = agent_class.new

        generated.generate("Latest Ruby?")
        streamed.stream("Latest Ruby?").to_a

        expect(streamed.session.messages.last.parts.map(&:to_h)).
          must_equal generated.session.messages.last.parts.map(&:to_h)
      end
    end

    # The API pauses after 10 server tool iterations, so twelve searches run one
    # at a time force a pause_turn and a continuation.
    it "finishes a turn the API paused, with every search answered" do
      VCR.use_cassette("Riffer_Providers_Anthropic/pause_turn/finishes_a_paused_turn") do
        result = provider.generate_text(
          prompt: "Look up the latest released version of each of these Ruby gems, one gem at a time: " \
                  "rails, rack, puma, sidekiq, nokogiri, devise, rspec, rubocop, faraday, pg, redis, sinatra. " \
                  "Run exactly one web search per step and read its result before you run the next one. " \
                  "Never run two searches in the same step. When you have all twelve, list each gem with its version.",
          model: "claude-haiku-5-5",
          web_search: { max_uses: 20 },
          thinking: { type: "disabled" },
          max_tokens: 8192,
        )
        server_tool_parts = result.parts.grep(Riffer::Messages::Assistant::ServerToolPart)
        call_ids = server_tool_parts.select { |part| part.kind == :call }.map(&:id)
        result_ids = server_tool_parts.select { |part| part.kind == :result }.map(&:id)

        assert_requested :post, "https://api.anthropic.com/v1/messages", at_least_times: 2
        expect([result.finish_reason, result.finish_reason_raw]).must_equal [:stop, "end_turn"]
        expect(call_ids.size).must_be :>, 10
        expect(result_ids).must_equal call_ids
      end
    end
  end

  describe "tool schema strict mode" do
    it "applies strict_schema to tool parameters" do
      tool = stub_tool("TestTool") do
        description "A test tool"
        params do
          required :name, :string
          optional :age, :integer
        end
      end

      provider = Riffer::Providers::Anthropic.new
      format = provider.send(:convert_tool, tool)
      schema = format[:input_schema]

      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
    end
  end

  describe "reasoning level" do
    let(:provider) { Riffer::Providers::Anthropic.new }
    let(:prompt) { "What is 17 times 23? Reply with just the number." }

    it "maps :off to disabled thinking" do
      expect(provider.send(:default_reasoning_options, :off)).must_equal({ thinking: { type: "disabled" } })
    end

    it "maps every other level to adaptive thinking at that effort" do
      %i[low medium high xhigh max].each do |level|
        expect(provider.send(:default_reasoning_options, level)).must_equal(
          { thinking: { type: "adaptive" }, output_config: { effort: level.to_s } },
        )
      end
    end

    it "keeps the effort next to a structured output format" do
      params = Riffer::Params.new
      params.required(:answer, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      options = { riffer_reasoning_level: :low, structured_output: structured_output }
      merged = provider.send(:apply_reasoning, "claude-sonnet-4-6", options).except(:riffer_reasoning_level)
      request = provider.send(:build_request_params, [Riffer::Messages::User.new("Hello")], "claude-sonnet-4-6", merged)

      expect(request[:output_config].keys).must_equal %i[effort format]
      expect(request[:output_config][:effort]).must_equal "low"
    end

    describe "with a catalog entry" do
      before { Riffer.config.catalog_files = [REASONING_CATALOG_PATH] }
      after { Riffer.config.catalog_files = [] }

      it "sends the catalog's thinking budget and max_tokens for a budget model" do
        merged = provider.send(:apply_reasoning, "claude-haiku-4-5-20251001", { riffer_reasoning_level: :low })
        request = provider.send(
          :build_request_params,
          [Riffer::Messages::User.new(prompt)],
          "claude-haiku-4-5-20251001",
          merged.except(:riffer_reasoning_level),
        )

        expect(request[:thinking]).must_equal({ type: "enabled", budget_tokens: 1024 })
        expect(request[:max_tokens]).must_equal 5120
        expect(request).wont_include :output_config
      end
    end
  end

  describe "usage" do
    describe "normalization" do
      let(:provider) { Riffer::Providers::Anthropic.new }
      let(:cached_usage) do
        { input_tokens: 9, output_tokens: 16, cache_creation_input_tokens: 3, cache_read_input_tokens: 100 }
      end

      it "folds cache buckets into input_tokens" do
        token_usage = provider.send(:extract_token_usage, { usage: cached_usage })

        expect(token_usage.input_tokens).must_equal 112
      end

      it "passes cache_write_tokens through" do
        token_usage = provider.send(:extract_token_usage, { usage: cached_usage })

        expect(token_usage.cache_write_tokens).must_equal 3
      end

      it "passes cache_read_tokens through" do
        token_usage = provider.send(:extract_token_usage, { usage: cached_usage })

        expect(token_usage.cache_read_tokens).must_equal 100
      end

      it "treats unreported cache buckets as zero" do
        token_usage = provider.send(:extract_token_usage, { usage: { input_tokens: 9, output_tokens: 16 } })

        expect(token_usage.input_tokens).must_equal 9
      end

      it "returns nil without usage" do
        expect(provider.send(:extract_token_usage, {})).must_be_nil
      end
    end
  end

  describe "reasoning" do
    let(:model) { "claude-haiku-4-5-20251001" }
    let(:provider) { Riffer::Providers::Anthropic.new }

    def thinking_block(thinking, signature) = { type: "thinking", thinking: thinking, signature: signature }
    def redacted_thinking_block(data) = { type: "redacted_thinking", data: data }
    def text_block(text) = { type: "text", text: text }

    def build_response(content_blocks)
      { content: content_blocks, usage: { input_tokens: 1, output_tokens: 1 }, stop_reason: "end_turn" }
    end

    def thinking_events(index, *chunks, signature: "sig")
      [
        block_start(index, { type: "thinking", thinking: "", signature: "" }),
        *chunks.map { |chunk| delta(index, { type: "thinking_delta", thinking: chunk }) },
        delta(index, { type: "signature_delta", signature: signature }),
        block_stop(index),
      ]
    end

    def text_events(index, *chunks)
      [
        block_start(index, { type: "text", text: "" }),
        *chunks.map { |chunk| delta(index, { type: "text_delta", text: chunk }) },
        block_stop(index),
      ]
    end

    def redacted_events(index, data)
      [block_start(index, redacted_thinking_block(data)), block_stop(index)]
    end

    def part(**attributes)
      Riffer::Messages::Assistant::ReasoningPart.new(**attributes)
    end

    def reasoning_of(response)
      provider.send(:extract_parts, response).grep(Riffer::Messages::Assistant::ReasoningPart)
    end

    def search_call_block = { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: { query: "ruby" } }
    def search_result_block = { type: "web_search_tool_result", tool_use_id: "srvtoolu_1", content: [] }

    def code_call_block
      { type: "server_tool_use", id: "srvtoolu_ce", name: "code_execution", input: { code: "print(1)" } }
    end

    def code_result_block
      { type: "code_execution_tool_result", tool_use_id: "srvtoolu_ce",
        content: { type: "code_execution_result", stdout: "1" }, }
    end

    def cited_text_block(text)
      { type: "text", text: text, citations: [{ type: "web_search_result_location", url: "https://ruby-lang.org", encrypted_index: "Eo8B" }] }
    end

    def convert(reasoning, content: "42", tool_calls: [])
      assistant = Riffer::Messages::Assistant.new(content, reasoning: reasoning, tool_calls: tool_calls)
      provider.send(:convert_assistant, assistant)
    end

    describe "capturing thinking blocks" do
      it "maps a thinking block onto a text part, keeping its signature" do
        response = build_response([thinking_block("Think", "sig"), text_block("42")])

        expect(reasoning_of(response).map(&:to_h)).must_equal [
          { type: :text, text: "Think", signature: "sig", format: "anthropic-messages-v1" },
        ]
      end

      it "maps a redacted_thinking block onto an encrypted part" do
        response = build_response([redacted_thinking_block("opaque")])

        expect(reasoning_of(response).map(&:to_h)).must_equal [
          { type: :encrypted, data: "opaque", format: "anthropic-messages-v1" },
        ]
      end

      it "keeps several reasoning blocks in response order" do
        response = build_response([thinking_block("One", "sig-1"), redacted_thinking_block("opaque")])

        expect(reasoning_of(response).map(&:type)).must_equal %i[text encrypted]
      end

      it "returns no parts when the response carries no thinking" do
        expect(reasoning_of(build_response([text_block("42")]))).must_equal []
      end

      it "keeps every block as a part, in response order" do
        response = build_response(
          [
            text_block("Searching. "),
            search_call_block,
            search_result_block,
            thinking_block("Think", "sig"),
            text_block("Ruby 4.0.1"),
            text_block(" is out."),
            { type: "tool_use", id: "toolu_1", name: "get_weather", input: {} },
          ],
        )
        provider.instance_variable_set(:@current_tools, [])

        message = Riffer::Messages::Assistant.new(parts: provider.send(:extract_parts, response))

        expect(message.parts.map { |part| part.class.name.split("::").last }).must_equal %w[
          TextPart ServerToolPart ServerToolPart ReasoningPart TextPart TextPart ToolCall
        ]
        expect(message.content).must_equal "Searching. Ruby 4.0.1 is out."
      end

      it "maps web search blocks onto server tool parts holding the block" do
        call, result = provider.send(:extract_parts, build_response([search_call_block, search_result_block]))

        expect([call.name, call.kind, call.id,
                call.format,]).must_equal ["web_search", :call, "srvtoolu_1", "anthropic-messages-v1"]
        expect([result.name, result.kind, result.id]).must_equal ["web_search", :result, "srvtoolu_1"]
        expect(JSON.parse(result.data, symbolize_names: true)).must_equal search_result_block
      end

      it "sends a code execution call back with its result, around the web search it ran" do
        blocks = [code_call_block, search_call_block, search_result_block, code_result_block, text_block("4.0.9")]
        message = Riffer::Messages::Assistant.new(parts: provider.send(:extract_parts, build_response(blocks)))

        expect(message.parts.grep(Riffer::Messages::Assistant::ServerToolPart).map { |p| [p.name, p.kind] }).
          must_equal [["code_execution", :call], ["web_search", :call], ["web_search", :result],
                      ["code_execution", :result],]
        expect(provider.send(:convert_assistant, message)[:content]).must_equal blocks
      end

      it "drops an MCP tool result along with its call" do
        blocks = [
          { type: "mcp_tool_use", id: "mcptoolu_1", name: "echo", server_name: "demo", input: {} },
          { type: "mcp_tool_result", tool_use_id: "mcptoolu_1", is_error: false, content: [] },
          text_block("done"),
        ]

        expect(provider.send(:extract_parts, build_response(blocks))).
          must_equal [Riffer::Messages::Assistant::TextPart.new("done")]
      end

      it "keeps a text block's citations, and only the text when it has none" do
        cited, plain = provider.send(:extract_parts, build_response([cited_text_block("4.0.9"), text_block(".")]))

        expect(JSON.parse(cited.data, symbolize_names: true)).must_equal cited_text_block("4.0.9")
        expect(cited.format).must_equal "anthropic-messages-v1"
        expect(plain).must_equal Riffer::Messages::Assistant::TextPart.new(".")
      end

      it "attaches the parts to the assistant message from generate_text" do
        response = build_response([thinking_block("Think", "sig"), text_block("42")])
        client = Object.new
        client.define_singleton_method(:post) { |_path, _body| response }
        provider.instance_variable_set(:@client, client)

        result = provider.generate_text(prompt: "Hi", model: model)

        expect(result.content).must_equal "42"
        expect(result.reasoning.map(&:to_h)).must_equal [
          { type: :text, text: "Think", signature: "sig", format: "anthropic-messages-v1" },
        ]
      end
    end

    describe "streaming thinking blocks" do
      it "captures a streamed redacted_thinking block as an encrypted part" do
        events = stream_events(redacted_events(0, "opaque"))

        expect(events.grep(Riffer::StreamEvents::ReasoningDelta)).must_be_empty
        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.to_h }).must_equal [
          { type: :encrypted, data: "opaque", format: "anthropic-messages-v1" },
        ]
      end

      it "keeps a signed thinking block whose text is empty" do
        events = stream_events(thinking_events(0))

        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.to_h }).must_equal [
          { type: :text, text: "", signature: "sig", format: "anthropic-messages-v1" },
        ]
      end

      it "emits a ServerToolDone for each web search block, ahead of its display event" do
        events = stream_events(
          [
            block_start(0, search_call_block.merge(input: {})),
            delta(0, { type: "input_json_delta", partial_json: '{"query":"ruby"}' }),
            block_stop(0),
            block_start(1, search_result_block),
            block_stop(1),
          ],
        )
        kinds = events.filter_map do |event|
          case event
          when Riffer::StreamEvents::ServerToolDone then event.part.kind
          when Riffer::StreamEvents::WebSearchStatus, Riffer::StreamEvents::WebSearchDone
            event.class.name.split("::").last
          end
        end

        expect(kinds).must_equal [:call, "WebSearchStatus", :result, "WebSearchDone"]
        call = events.grep(Riffer::StreamEvents::ServerToolDone).first.part

        expect(JSON.parse(call.data,
                          symbolize_names: true,)).must_equal search_call_block.merge(input: { query: "ruby" })
      end

      it "emits a ServerToolDone for a code execution result, without a web search event" do
        events = stream_events(
          [
            block_start(0, code_call_block.merge(input: {})),
            delta(0, { type: "input_json_delta", partial_json: '{"code":"print(1)"}' }),
            block_stop(0),
            block_start(1, code_result_block),
            block_stop(1),
          ],
        )

        expect(events.grep(Riffer::StreamEvents::ServerToolDone).map { |e| [e.part.name, e.part.kind] }).
          must_equal [["code_execution", :call], ["code_execution", :result]]
        expect(events.grep(Riffer::StreamEvents::WebSearchDone)).must_be_empty
      end

      it "emits parts in block order and leaves the following text block intact" do
        events = stream_events(
          [*thinking_events(0, "First", signature: "sig-1"), *redacted_events(1, "opaque"), *text_events(2, "4", "2")],
        )

        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.type }).must_equal %i[text encrypted]
        expect(events.grep(Riffer::StreamEvents::TextDone).map(&:content)).must_equal ["42"]
      end
    end

    describe "replaying reasoning" do
      it "sends recognized parts as thinking blocks ahead of text and tool_use, in order" do
        reasoning = [
          part(type: :text, text: "Think", signature: "sig", format: "anthropic-messages-v1"),
          part(type: :encrypted, data: "opaque", format: "anthropic-messages-v1"),
        ]
        tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "toolu_1", name: "get_weather", arguments: "{}")

        content = convert(reasoning, tool_calls: [tool_call])[:content]

        expect(content[0]).must_equal({ type: "thinking", thinking: "Think", signature: "sig" })
        expect(content[1]).must_equal({ type: "redacted_thinking", data: "opaque" })
        expect(content[2]).must_equal({ type: "text", text: "42" })
        expect(content[3][:type]).must_equal "tool_use"
      end

      it "sends every block back in its original order, unchanged, after a JSON round trip" do
        blocks = [
          text_block("Let me check."),
          search_call_block,
          search_result_block,
          thinking_block("Think", "sig"),
          cited_text_block("4.0.9"),
        ]
        message = Riffer::Messages::Assistant.new(parts: provider.send(:extract_parts, build_response(blocks)))
        json = JSON.generate(message.to_h)
        restored = Riffer::Messages::Base.from_hash(JSON.parse(json, symbolize_names: true))

        expect(provider.send(:convert_assistant, restored)[:content]).must_equal blocks
      end

      it "skips server tool parts and text blocks from another adapter, keeping the text" do
        message = Riffer::Messages::Assistant.new(
          parts: [
            Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: :call, data: "{}",
                                                            format: "mock-v1",),
            Riffer::Messages::Assistant::TextPart.new("42", data: '{"type":"output_text"}', format: "mock-v1"),
            Riffer::Messages::Assistant::TextPart.new(""),
          ],
        )

        expect(provider.send(:convert_assistant, message)[:content]).must_equal [{ type: "text", text: "42" }]
      end

      it "sends no whitespace-only text block for the separator added when merging assistant messages" do
        blocks = [text_block("Let me check."), search_call_block, search_result_block]
        first = Riffer::Messages::Assistant.new(parts: provider.send(:extract_parts, build_response(blocks)))
        merged = first + Riffer::Messages::Assistant.new("Done.")
        messages = [Riffer::Messages::User.new("Hi"), merged]

        params = provider.send(:build_request_params, messages, "claude-haiku-4-5-20251001", {})

        expect(params[:messages].last[:content]).must_equal [*blocks, text_block("Done.")]
      end

      it "replays parts restored from a persisted hash" do
        captured = reasoning_of(build_response([thinking_block("Think", "sig")]))
        persisted = captured.map { |p| JSON.parse(p.to_h.to_json, symbolize_names: true) }
        restored = persisted.map { |h| Riffer::Messages::Assistant::ReasoningPart.from_hash(h) }

        expect(convert(restored)[:content].first).must_equal({ type: "thinking", thinking: "Think", signature: "sig" })
      end

      it "replays a text part with no text as an empty thinking string" do
        reasoning = [part(type: :text, text: nil, signature: "sig", format: "anthropic-messages-v1")]

        expect(convert(reasoning)[:content].first).must_equal({ type: "thinking", thinking: "", signature: "sig" })
      end

      it "skips parts with no format or another adapter's format" do
        reasoning = [
          part(type: :text, text: "legacy"),
          part(type: :text, text: "foreign", signature: "sig", format: "anthropic-claude-v1"),
          part(type: :text, text: "kept", signature: "sig", format: "anthropic-messages-v1"),
        ]

        expect(convert(reasoning)[:content]).must_equal [
          { type: "thinking", thinking: "kept", signature: "sig" },
          { type: "text", text: "42" },
        ]
      end

      it "omits thinking blocks when no part is replayable" do
        expect(convert([part(type: :text, text: "legacy", format: "mock-v1")])[:content]).must_equal [
          { type: "text", text: "42" },
        ]
      end
    end
  end
end
