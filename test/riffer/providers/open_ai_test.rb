# frozen_string_literal: true

require "test_helper"
require "openai"

describe Riffer::Providers::OpenAI do
  before { Riffer.config.openai.api_key = "test_api_key" }

  after do
    Riffer.config.openai.api_key = nil
    Riffer.config.openai.base_url = nil
    Riffer.config.openai.client = nil
  end

  def install_stream_double(provider, stream_double)
    responses_double = Object.new
    responses_double.define_singleton_method(:stream) { |_params| stream_double }
    client_double = Object.new
    client_double.define_singleton_method(:responses) { responses_double }
    provider.instance_variable_set(:@client, client_double)
  end

  def stream_events(provider, events)
    events += [Struct.new(:type, :response).new(:"response.completed", nil)]
    stream_double = Object.new
    stream_double.define_singleton_method(:each) { |&block| events.each(&block) }
    stream_double.define_singleton_method(:close) { nil }
    install_stream_double(provider, stream_double)
    provider.stream_text(prompt: "Hi", model: "gpt-5-mini").to_a
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::OpenAI.semconv_provider_name).must_equal "openai"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::OpenAI.new }

    it "derives stop from a completed response without tool calls" do
      response = Struct.new(:status, :output).new(:completed, [])
      finish_reason = provider.send(:build_finish_reason, response)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:stop, "completed"]
    end

    it "derives length from an incomplete response over max tokens" do
      details = Struct.new(:reason).new(:max_output_tokens)
      response = Struct.new(:status, :incomplete_details).new(:incomplete, details)
      finish_reason = provider.send(:build_finish_reason, response)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:length, "max_output_tokens"]
    end

    it "derives content_filter from a filtered incomplete response" do
      details = Struct.new(:reason).new(:content_filter)
      response = Struct.new(:status, :incomplete_details).new(:incomplete, details)

      expect(provider.send(:build_finish_reason, response).reason).must_equal :content_filter
    end

    it "derives other from an incomplete response without details" do
      response = Struct.new(:status, :incomplete_details).new(:incomplete, nil)
      finish_reason = provider.send(:build_finish_reason, response)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "incomplete"]
    end

    it "derives error from a failed response and keeps the error code as raw" do
      error = Struct.new(:code).new(:rate_limit_exceeded)
      response = Struct.new(:status, :error).new(:failed, error)
      finish_reason = provider.send(:build_finish_reason, response)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:error, "rate_limit_exceeded"]
    end

    it "falls back to failed as raw when a failed response carries no error code" do
      response = Struct.new(:status, :error).new(:failed, nil)
      finish_reason = provider.send(:build_finish_reason, response)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:error, "failed"]
    end

    it "returns nil without a status" do
      response = Struct.new(:status).new(nil)

      expect(provider.send(:build_finish_reason, response)).must_be_nil
    end

    it "maps each status without a nested detail, keeping the status as raw" do
      derived = %w[completed failed cancelled in_progress queued].to_h do |status|
        response = Struct.new(:status, :output, :error).new(status.to_sym, [], nil)
        finish_reason = provider.send(:build_finish_reason, response)
        [status, [finish_reason.reason, finish_reason.raw]]
      end

      expect(derived).must_equal(
        "completed" => [:stop, "completed"],
        "failed" => [:error, "failed"],
        "cancelled" => [:other, "cancelled"],
        "in_progress" => [:other, "in_progress"],
        "queued" => [:other, "queued"],
      )
    end

    it "covers every response status the SDK defines" do
      statuses = OpenAI::Models::Responses::ResponseStatus.values.map(&:to_s)

      expect(Riffer::Providers::OpenAI::FINISH_REASONS.keys.sort).must_equal statuses.sort
    end
  end

  describe "#initialize" do
    it "creates the provider" do
      provider = Riffer::Providers::OpenAI.new

      expect(provider).must_be_instance_of Riffer::Providers::OpenAI
    end

    it "takes no arguments" do
      expect { Riffer::Providers::OpenAI.new(api_key: "test_api_key") }.must_raise ArgumentError
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::OpenAI.new(organization: "org-123") }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "uses the configured client" do
      configured = Object.new
      Riffer.config.openai.client = configured

      expect(Riffer::Providers::OpenAI.new.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.openai.client = -> { calls += 1 }
      provider = Riffer::Providers::OpenAI.new

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      provider = Riffer::Providers::OpenAI.new

      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "prefers a configured client over configured credentials" do
      configured = Object.new
      Riffer.config.openai.client = configured

      expect(Riffer::Providers::OpenAI.new.send(:client)).must_be_same_as configured
    end

    it "lets the built client pick up OPENAI_BASE_URL" do
      original = ENV.fetch("OPENAI_BASE_URL", nil)
      ENV["OPENAI_BASE_URL"] = "https://gateway.example/v1"

      expect(Riffer::Providers::OpenAI.new.send(:client).base_url.to_s).must_equal "https://gateway.example/v1"
    ensure
      ENV["OPENAI_BASE_URL"] = original
    end

    it "prefers a configured base_url over OPENAI_BASE_URL" do
      original = ENV.fetch("OPENAI_BASE_URL", nil)
      ENV["OPENAI_BASE_URL"] = "https://gateway.example/v1"
      Riffer.config.openai.base_url = "https://localhost:4000/v1"

      expect(Riffer::Providers::OpenAI.new.send(:client).base_url.to_s).must_equal "https://localhost:4000/v1"
    ensure
      ENV["OPENAI_BASE_URL"] = original
    end

    it "lets the built client pick up OPENAI_API_KEY" do
      original = ENV.fetch("OPENAI_API_KEY", nil)
      ENV["OPENAI_API_KEY"] = "sk-from-env"
      Riffer.config.openai.api_key = nil

      expect(Riffer::Providers::OpenAI.new.send(:client).api_key).must_equal "sk-from-env"
    ensure
      ENV["OPENAI_API_KEY"] = original
    end

    it "prefers a configured api_key over OPENAI_API_KEY" do
      original = ENV.fetch("OPENAI_API_KEY", nil)
      ENV["OPENAI_API_KEY"] = "sk-from-env"
      Riffer.config.openai.api_key = "sk-from-config"

      expect(Riffer::Providers::OpenAI.new.send(:client).api_key).must_equal "sk-from-config"
    ensure
      ENV["OPENAI_API_KEY"] = original
      Riffer.config.openai.api_key = nil
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::OpenAI.new }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }

    # Run normalizes tags before they reach the provider, so these pass clean String maps.
    it "maps all tags to metadata" do
      params = provider.send(
        :build_request_params,
        messages,
        "gpt-5-mini",
        { tags: { "team" => "growth", "user_id" => "u_1" } },
      )

      expect(params[:metadata]).must_equal({ "team" => "growth", "user_id" => "u_1" })
    end

    it "merges tags over metadata set in model_options" do
      params = provider.send(
        :build_request_params,
        messages,
        "gpt-5-mini",
        { metadata: { "env" => "prod", "team" => "ops" }, tags: { "team" => "growth" } },
      )

      expect(params[:metadata]).must_equal({ "env" => "prod", "team" => "growth" })
    end

    it "maps the reserved user_id to safety_identifier while keeping it in metadata" do
      params = provider.send(:build_request_params, messages, "gpt-5-mini", { tags: { "user_id" => "u_1" } })

      expect([params[:safety_identifier], params[:metadata]]).must_equal(["u_1", { "user_id" => "u_1" }])
    end

    it "omits safety_identifier when no user_id tag is present" do
      params = provider.send(:build_request_params, messages, "gpt-5-mini", { tags: { "team" => "growth" } })

      expect(params.key?(:safety_identifier)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, "gpt-5-mini", { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end
  end

  describe "reasoning" do
    let(:provider) { Riffer::Providers::OpenAI.new }

    def reasoning_item(id:, summary: [], content: nil, encrypted_content: nil)
      OpenAI::Models::Responses::ResponseReasoningItem.new(
        id: id,
        summary: summary.map { |text| OpenAI::Models::Responses::ResponseReasoningItem::Summary.new(text: text) },
        **{
          content: content&.map { |text| OpenAI::Models::Responses::ResponseReasoningItem::Content.new(text: text) },
          encrypted_content: encrypted_content,
        }.compact,
      )
    end

    def response_with(output)
      OpenAI::Models::Responses::Response.new(output: output)
    end

    def part(**attributes)
      Riffer::Messages::Assistant::ReasoningPart.new(**attributes)
    end

    def convert(reasoning, content: "42", tool_calls: [])
      assistant = Riffer::Messages::Assistant.new(content, reasoning: reasoning, tool_calls: tool_calls)
      provider.send(:convert_assistant_to_openai_format, assistant)
    end

    describe "capturing reasoning items" do
      it "maps each summary, content entry, and the encrypted payload onto parts sharing the item id" do
        response = response_with(
          [reasoning_item(id: "rs_1", summary: %w[One Two], content: ["Think"], encrypted_content: "b3Bh")],
        )

        expect(provider.send(:extract_reasoning, response).map(&:to_h)).must_equal [
          { type: :summary, text: "One", id: "rs_1", format: "openai-v1" },
          { type: :summary, text: "Two", id: "rs_1", format: "openai-v1" },
          { type: :text, text: "Think", id: "rs_1", format: "openai-v1" },
          { type: :encrypted, data: "b3Bh", id: "rs_1", format: "openai-v1" },
        ]
      end

      it "keeps an encrypted part carrying the id when the item has no summary or payload" do
        response = response_with([reasoning_item(id: "rs_1")])

        expect(provider.send(:extract_reasoning, response).map(&:to_h)).must_equal [
          { type: :encrypted, id: "rs_1", format: "openai-v1" },
        ]
      end

      it "returns no parts when the response carries no reasoning item" do
        expect(provider.send(:extract_reasoning, response_with([]))).must_equal []
      end
    end

    describe "streaming reasoning items" do
      let(:event_struct) { Struct.new(:type, :item, :response) }

      it "yields one ReasoningDone per part when a reasoning item completes, in item order" do
        events = stream_events(
          provider,
          [
            event_struct.new(type: :"response.output_item.done", item: reasoning_item(id: "rs_1", summary: ["Sum"])),
            event_struct.new(type: :"response.output_item.done",
                             item: reasoning_item(id: "rs_2", encrypted_content: "b3Bh"),),
          ],
        )

        expect(events.grep(Riffer::StreamEvents::ReasoningDone).map { |e| e.part.to_h }).must_equal [
          { type: :summary, text: "Sum", id: "rs_1", format: "openai-v1" },
          { type: :encrypted, id: "rs_1", format: "openai-v1" },
          { type: :encrypted, data: "b3Bh", id: "rs_2", format: "openai-v1" },
        ]
      end

      it "yields a ReasoningDelta per reasoning summary delta" do
        summary_delta = Struct.new(:type, :delta)
        events = stream_events(
          provider,
          [
            summary_delta.new(:"response.reasoning_summary_text.delta", "Adding "),
            summary_delta.new(:"response.reasoning_summary_text.delta", "it up."),
          ],
        )

        expect(events.grep(Riffer::StreamEvents::ReasoningDelta).map(&:content)).must_equal ["Adding ", "it up."]
      end
    end

    describe "replaying reasoning" do
      it "sends each run of parts sharing an id back as one reasoning item ahead of the message" do
        reasoning = [
          part(type: :summary, text: "One", id: "rs_1", format: "openai-v1"),
          part(type: :summary, text: "Two", id: "rs_1", format: "openai-v1"),
          part(type: :encrypted, data: "b3Bh", id: "rs_1", format: "openai-v1"),
          part(type: :text, text: "Think", id: "rs_2", format: "openai-v1"),
          part(type: :encrypted, id: "rs_2", format: "openai-v1"),
        ]

        expect(convert(reasoning)).must_equal [
          {
            type: "reasoning",
            id: "rs_1",
            summary: [{ type: "summary_text", text: "One" }, { type: "summary_text", text: "Two" }],
            encrypted_content: "b3Bh",
          },
          { type: "reasoning", id: "rs_2", summary: [], content: [{ type: "reasoning_text", text: "Think" }] },
          { role: "assistant", content: "42" },
        ]
      end

      it "replays text and summary parts with no text as empty strings" do
        reasoning = [
          part(type: :summary, text: nil, id: "rs_1", format: "openai-v1"),
          part(type: :text, text: nil, id: "rs_1", format: "openai-v1"),
        ]

        expect(convert(reasoning).first).must_equal(
          {
            type: "reasoning",
            id: "rs_1",
            summary: [{ type: "summary_text", text: "" }],
            content: [{ type: "reasoning_text", text: "" }],
          },
        )
      end

      it "places reasoning ahead of the function calls it produced" do
        tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "call_1", name: "get_weather", arguments: "{}")

        items = convert([part(type: :encrypted, id: "rs_1", format: "openai-v1")], content: "", tool_calls: [tool_call])

        expect(items.map { |item| item[:type] }).must_equal %w[reasoning function_call]
      end

      it "skips parts with no format or another adapter's format" do
        reasoning = [
          part(type: :text, text: "legacy"),
          part(type: :encrypted, data: "b3Bh", id: "rs_x", format: "openai-responses-v1"),
          part(type: :encrypted, data: "b3Bh", id: "rs_y", format: "azure-openai-v1"),
        ]

        expect(convert(reasoning)).must_equal [{ role: "assistant", content: "42" }]
      end
    end
  end

  describe "reasoning level" do
    let(:provider) { Riffer::Providers::OpenAI.new }
    let(:messages) { [Riffer::Messages::User.new("Hi")] }

    it "maps :off to effort none" do
      expect(provider.send(:default_reasoning_options, :off)).must_equal({ reasoning: "none" })
    end

    it "passes every other level through as the effort" do
      %i[low medium high xhigh max].each do |level|
        expect(provider.send(:default_reasoning_options, level)).must_equal({ reasoning: level.to_s })
      end
    end

    it "sends effort none for :off" do
      options = provider.send(:apply_reasoning, "gpt-5.1", { riffer_reasoning_level: :off })
      params = provider.send(:build_request_params, messages, "gpt-5.1", provider.send(:request_options, options))

      expect(params[:reasoning]).must_equal({ effort: "none", summary: "auto" })
    end

    it "sends no reasoning without a reasoning level or option" do
      params = provider.send(:build_request_params, messages, "gpt-5-mini", {})

      expect(params).wont_include :reasoning
    end
  end

  describe "structured output" do
    it "includes text.format in request params" do
      provider = Riffer::Providers::OpenAI.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      params.required(:score, :number)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })

      expect(params[:text][:format][:type]).must_equal "json_schema"
    end

    it "sets schema name to response" do
      provider = Riffer::Providers::OpenAI.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })

      expect(params[:text][:format][:name]).must_equal "response"
    end

    it "sets strict to true" do
      provider = Riffer::Providers::OpenAI.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })

      expect(params[:text][:format][:strict]).must_equal true
    end

    it "includes json_schema in format" do
      provider = Riffer::Providers::OpenAI.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })

      expect(params[:text][:format][:schema][:type]).must_equal "object"
    end

    it "does not include text.format when not configured" do
      provider = Riffer::Providers::OpenAI.new
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "gpt-5-mini", {})

      expect(params[:text]).must_be_nil
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::OpenAI.new
      params = Riffer::Params.new
      params.required(:sentiment, :string)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })

      expect(params.key?(:structured_output)).must_equal false
    end

    it "puts all properties in required for strict mode" do
      provider = Riffer::Providers::OpenAI.new
      p = Riffer::Params.new
      p.required(:name, :string)
      p.optional(:age, :integer)
      structured_output = Riffer::Agent::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })
      schema = result[:text][:format][:schema]

      expect(schema[:required]).must_equal %w[name age]
    end

    it "makes optional properties nullable for strict mode" do
      provider = Riffer::Providers::OpenAI.new
      p = Riffer::Params.new
      p.required(:name, :string)
      p.optional(:age, :integer)
      structured_output = Riffer::Agent::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })
      schema = result[:text][:format][:schema]

      expect(schema[:properties]["name"][:type]).must_equal "string"
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
    end

    it "makes nested optional properties nullable for strict mode" do
      provider = Riffer::Providers::OpenAI.new
      p = Riffer::Params.new
      p.required(:address, :object) do
        required :city, :string
        optional :zip, :string
      end
      structured_output = Riffer::Agent::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })
      address = result[:text][:format][:schema][:properties]["address"]

      expect(address[:required]).must_equal %w[city zip]
      expect(address[:properties]["city"][:type]).must_equal "string"
      expect(address[:properties]["zip"][:type]).must_equal %w[string null]
    end

    it "makes optional properties in array items nullable for strict mode" do
      provider = Riffer::Providers::OpenAI.new
      p = Riffer::Params.new
      p.required(:items, :array) do
        required :sku, :string
        optional :notes, :string
      end
      structured_output = Riffer::Agent::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-mini", { structured_output: structured_output })
      items_schema = result[:text][:format][:schema][:properties]["items"][:items]

      expect(items_schema[:required]).must_equal %w[sku notes]
      expect(items_schema[:properties]["sku"][:type]).must_equal "string"
      expect(items_schema[:properties]["notes"][:type]).must_equal %w[string null]
    end

    it "validates successfully when nullable optional fields return null" do
      p = Riffer::Params.new
      p.required(:name, :string)
      p.optional(:age, :integer)
      p.required(:address, :object) do
        required :city, :string
        optional :zip, :string
      end
      structured_output = Riffer::Agent::StructuredOutput.new(p)

      result = structured_output.parse_and_validate(
        '{"name":"John","age":null,"address":{"city":"Toronto","zip":null}}',
      )

      expect(result.success?).must_equal true
      expect(result.object[:name]).must_equal "John"
      expect(result.object[:age]).must_be_nil
      expect(result.object[:address][:city]).must_equal "Toronto"
      expect(result.object[:address][:zip]).must_be_nil
    end
  end

  describe "web search" do
    let(:provider) { Riffer::Providers::OpenAI.new }
    let(:messages) { [Riffer::Messages::User.new("Hi")] }
    let(:sources_include) { Riffer::Providers::OpenAI::WEB_SEARCH_SOURCES_INCLUDE }

    it "asks for the search sources" do
      params = provider.send(:build_request_params, messages, "gpt-5-mini", { web_search: true })

      expect(params[:include]).must_equal [sources_include]
    end

    it "keeps the include entries the caller passed" do
      params = provider.send(
        :build_request_params,
        messages,
        "gpt-5-mini",
        { web_search: true, include: ["reasoning.encrypted_content"] },
      )

      expect(params[:include]).must_equal ["reasoning.encrypted_content", sources_include]
    end

    it "does not repeat a sources include the caller already passed" do
      params = provider.send(
        :build_request_params,
        messages,
        "gpt-5-mini",
        { web_search: true, include: [sources_include] },
      )

      expect(params[:include]).must_equal [sources_include]
    end

    it "does not repeat a sources include the caller passed as a Symbol" do
      params = provider.send(
        :build_request_params,
        messages,
        "gpt-5-mini",
        { web_search: true, include: [sources_include.to_sym] },
      )

      expect(params[:include]).must_equal [sources_include.to_sym]
    end

    it "sends no include without web search" do
      params = provider.send(:build_request_params, messages, "gpt-5-mini", {})

      expect(params).wont_include :include
    end

    it "streams each search status ahead of the search's WebSearchDone" do
      source = OpenAI::Models::Responses::ResponseFunctionWebSearch::Action::Search::Source.new(
        type: :url,
        url: "https://www.ruby-lang.org",
      )
      search = OpenAI::Models::Responses::ResponseFunctionWebSearch.new(
        id: "ws_1",
        status: :completed,
        type: :web_search_call,
        action: OpenAI::Models::Responses::ResponseFunctionWebSearch::Action::Search.new(
          type: :search,
          query: "ruby",
          sources: [source],
        ),
      )
      status_event = Struct.new(:type)
      events = stream_events(
        provider,
        [
          status_event.new(:"response.web_search_call.in_progress"),
          status_event.new(:"response.web_search_call.searching"),
          status_event.new(:"response.web_search_call.completed"),
          Struct.new(:type, :item).new(:"response.output_item.done", search),
        ],
      )
      statuses = events.grep(Riffer::StreamEvents::WebSearchStatus)

      expect(statuses.map(&:status)).must_equal %w[in_progress searching completed]
      expect(events.index(statuses.last)).must_be :<, events.index(events.grep(Riffer::StreamEvents::WebSearchDone).first)
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

      provider = Riffer::Providers::OpenAI.new
      format = provider.send(:convert_tool_to_openai_format, tool)
      schema = format[:parameters]

      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
    end
  end

  describe "tool calling" do
    let(:provider) { Riffer::Providers::OpenAI.new }

    def function_call(number, status: :completed, arguments: '{"city":"Toronto"}')
      OpenAI::Models::Responses::ResponseFunctionToolCall.new(
        id: "fc_#{number}",
        call_id: "call_#{number}",
        name: "get_weather",
        arguments: arguments,
        status: status,
        type: :function_call,
      )
    end

    def output_item(type, item)
      Struct.new(:type, :item).new(:"response.output_item.#{type}", item)
    end

    it "yields a ToolCallDelta per arguments delta, named from the added item" do
      arguments_delta = Struct.new(:type, :item_id, :delta)
      events = stream_events(
        provider,
        [
          output_item(:added, function_call(1, status: :in_progress, arguments: "")),
          arguments_delta.new(:"response.function_call_arguments.delta", "fc_1", '{"city":'),
          arguments_delta.new(:"response.function_call_arguments.delta", "fc_1", '"Toronto"}'),
        ],
      )

      expect(events.grep(Riffer::StreamEvents::ToolCallDelta).map(&:to_h)).must_equal [
        { role: :assistant, item_id: "fc_1", name: "get_weather", arguments_delta: '{"city":' },
        { role: :assistant, item_id: "fc_1", name: "get_weather", arguments_delta: '"Toronto"}' },
      ]
    end

    it "streams no ToolCallDone for a function call cut off by max_output_tokens" do
      events = stream_events(
        provider,
        [
          output_item(:done, function_call(1)),
          Struct.new(:type, :item_id, :arguments).new(:"response.function_call_arguments.done", "fc_2", '{"city":"Pa'),
          output_item(:done, function_call(2, status: :incomplete, arguments: '{"city":"Pa')),
        ],
      )

      expect(events.grep(Riffer::StreamEvents::ToolCallDone).map(&:to_h)).must_equal [
        { role: :assistant, item_id: "fc_1", call_id: "call_1", name: "get_weather", arguments: '{"city":"Toronto"}' },
      ]
    end

    it "drops a function call cut off by max_output_tokens and keeps the completed one" do
      response = OpenAI::Models::Responses::Response.new(
        output: [function_call(1), function_call(2, status: :incomplete, arguments: '{"city":"Pa')],
        status: :incomplete,
        incomplete_details: OpenAI::Models::Responses::Response::IncompleteDetails.new(reason: :max_output_tokens),
      )
      responses_double = Object.new
      responses_double.define_singleton_method(:create) { |_params| response }
      client_double = Object.new
      client_double.define_singleton_method(:responses) { responses_double }
      Riffer.config.openai.client = client_double

      result = provider.generate_text(prompt: "Hi", model: "gpt-5-mini")

      expect(result.tool_calls.map(&:call_id)).must_equal ["call_1"]
    end
  end

  describe "multiple text parts" do
    let(:provider) { Riffer::Providers::OpenAI.new }

    def output_message(*texts)
      OpenAI::Models::Responses::ResponseOutputMessage.new(
        id: "msg_1",
        content: texts.map do |text|
          OpenAI::Models::Responses::ResponseOutputText.new(text: text, annotations: [], type: :output_text)
        end,
        role: :assistant,
        status: :completed,
        type: :message,
      )
    end

    def text_delta(delta)
      Struct.new(:type, :delta).new(:"response.output_text.delta", delta)
    end

    def text_done(text)
      Struct.new(:type, :text).new(:"response.output_text.done", text)
    end

    it "keeps every output_text part of every message item, in order" do
      refusal = OpenAI::Models::Responses::ResponseOutputRefusal.new(refusal: "no", type: :refusal)
      message_with_refusal = output_message("Let me ", "check. ")
      message_with_refusal.content << refusal
      tool_call = OpenAI::Models::Responses::ResponseFunctionToolCall.new(
        arguments: "{}", call_id: "call_1", name: "get_weather", type: :function_call,
      )
      response = Struct.new(:output).new([message_with_refusal, tool_call, output_message("The answer is 42.")])

      expect(provider.send(:extract_content, response)).must_equal "Let me check. The answer is 42."
    end

    it "yields one TextDone joining every streamed output_text part" do
      events = stream_events(
        provider,
        [
          text_delta("Let me "),
          text_delta("check. "),
          text_done("Let me check. "),
          text_delta("The answer "),
          text_delta("is 42."),
          text_done("The answer is 42."),
        ],
      )

      expect(events.grep(Riffer::StreamEvents::TextDone).map(&:content)).must_equal ["Let me check. The answer is 42."]
    end

    it "yields no TextDone when the stream carries no text" do
      expect(stream_events(provider, []).grep(Riffer::StreamEvents::TextDone)).must_be_empty
    end
  end

  describe "#stream_text resource cleanup" do
    let(:provider) { Riffer::Providers::OpenAI.new }

    it "calls stream.close when iteration raises mid-stream" do
      close_count = 0
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&_block| raise "kaboom" }
      stream_double.define_singleton_method(:close) { close_count += 1 }
      install_stream_double(provider, stream_double)

      assert_raises(RuntimeError) do
        provider.stream_text(prompt: "Hi", model: "gpt-5-mini").to_a
      end
      expect(close_count).must_equal 1
    end

    it "calls stream.close exactly once when the stream ends without a terminal event" do
      close_count = 0
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&_block| }
      stream_double.define_singleton_method(:close) { close_count += 1 }
      install_stream_double(provider, stream_double)

      assert_raises(Riffer::IncompleteStreamError) do
        provider.stream_text(prompt: "Hi", model: "gpt-5-mini").to_a
      end
      expect(close_count).must_equal 1
    end

    it "calls stream.close exactly once on happy path" do
      completed = Struct.new(:type, :response).new(:"response.completed", nil)
      close_count = 0
      stream_double = Object.new
      stream_double.define_singleton_method(:each) { |&block| block.call(completed) }
      stream_double.define_singleton_method(:close) { close_count += 1 }
      install_stream_double(provider, stream_double)

      provider.stream_text(prompt: "Hi", model: "gpt-5-mini").to_a

      expect(close_count).must_equal 1
    end
  end
end
