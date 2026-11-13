# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::DeferredToolGateway do
  let(:gateway) { Riffer::Providers::DeferredToolGateway }
  let(:gateway_name) { Riffer::Providers::DeferredToolGateway::Tool.name }

  let(:list_events) do
    stub_tool("ListEvents") do
      identifier "calendar/list_events"
      description "Lists calendar events"
      params { required :date, :string, description: "The date, as YYYY-MM-DD" }
    end
  end

  let(:create_event) { stub_tool("CreateEvent") { description "Creates a calendar event" } }
  let(:deferred) { [list_events, create_event] }

  def tool_call(name, id, arguments = "{}")
    Riffer::Messages::Assistant::ToolCall.new(call_id: id, name: name, arguments: arguments)
  end

  def gateway_call(id, arguments)
    tool_call(gateway_name, id, arguments)
  end

  def result(id, name, content: "", loaded: [], error: nil)
    Riffer::Messages::Tool.new(content, tool_call_id: id, name: name, loaded_tools: loaded, error: error)
  end

  describe "Tool" do
    let(:tool) { Riffer::Providers::DeferredToolGateway::Tool }
    let(:schema) do
      {
        type: "object",
        properties: {
          "name" => { type: "string",
                      description: "The loaded tool's exact name, copied from the result that loaded it", },
          "arguments" => {
            type: "string",
            description: "The loaded tool's arguments as a JSON-encoded object string matching its parameters, such " \
                         "as \"{\\\"query\\\":\\\"red shoes\\\",\\\"limit\\\":5}\". Numbers and booleans stay " \
                         "unquoted inside it. Use \"{}\" for a tool without parameters.",
          },
        },
        required: %w[name arguments],
        additionalProperties: false,
      }
    end

    it "is a valid tool named riffer_gateway" do
      expect([tool.name, tool.validate_as_tool!]).must_equal ["riffer_gateway", true]
    end

    it "takes a string name and string arguments, both required, with no other properties" do
      expect(tool.parameters_schema).must_equal schema
    end

    it "has the same schema in strict mode, with no free-form object" do
      expect(tool.parameters_schema(strict: true)).must_equal schema
    end
  end

  describe ".wrap_messages" do
    it "re-encodes a call to a deferred tool as a gateway call with the same id" do
      assistant = Riffer::Messages::Assistant.new(
        "Checking",
        id: "msg_1",
        tool_calls: [tool_call("calendar/list_events", "c_1", '{"date":"2026-11-06"}'),
                     tool_call("get_weather", "c_2"),],
      )

      wrapped = gateway.wrap_messages([assistant], deferred).first

      expect(wrapped.id).must_equal "msg_1"
      expect(wrapped.content).must_equal "Checking"
      expect(wrapped.tool_calls).must_equal [
        gateway_call("c_1", '{"name":"calendar/list_events","arguments":"{\"date\":\"2026-11-06\"}"}'),
        tool_call("get_weather", "c_2"),
      ]
    end

    it "renames a deferred tool's result to the gateway and keeps its tool_call_id and content" do
      wrapped = gateway.wrap_messages([result("c_1", "calendar/list_events", content: "3 events")], deferred).first

      expect([wrapped.tool_call_id, wrapped.name, wrapped.content]).must_equal ["c_1", gateway_name, "3 events"]
    end

    it "appends each loaded tool's name, description and parameters to the result that loaded it" do
      loading = result("c_1", "connect_calendar", loaded: %w[create_event calendar/list_events])

      wrapped = gateway.wrap_messages([loading], deferred).first

      expect(wrapped.name).must_equal "connect_calendar"
      expect(wrapped.content).must_equal <<~TEXT.chomp
        These tools are now loaded. They are not in your tool list, so calling one by its own name fails. Call each one through the riffer_gateway tool: set name to the tool's name exactly as written below, and set arguments to a string holding its arguments as a JSON object that matches its parameters. Use "{}" as arguments for a tool without parameters.

        [{"name":"calendar/list_events","description":"Lists calendar events","parameters":{"type":"object","properties":{"date":{"type":"string","description":"The date, as YYYY-MM-DD"}},"required":["date"],"additionalProperties":false}},{"name":"create_event","description":"Creates a calendar event","parameters":{"type":"object","properties":{},"required":[],"additionalProperties":false}}]
      TEXT
    end

    it "keeps a loading result's own content ahead of the description" do
      loading = result("c_1", "connect_calendar", content: "Connected.", loaded: ["create_event"])

      content = gateway.wrap_messages([loading], deferred).first.content

      expect(content).must_match(/\AConnected\.\n\nThese tools are now loaded\./)
    end

    it "describes a body-less tool shell from its stored schema" do
      descriptor = JSON.parse(Riffer::Agent::Serializer.send(:tool_descriptor, list_events).to_json,
                              symbolize_names: true,)
      shell = Riffer::Agent::Serializer::DEFAULT_TOOL_RESOLVER.call(descriptor)
      loading = result("c_1", "connect_calendar", loaded: ["calendar/list_events"])

      expect(gateway.wrap_messages([loading], [shell]).first.content).
        must_equal gateway.wrap_messages([loading], [list_events]).first.content
    end

    it "describes nothing for an error result or a name that isn't deferred" do
      messages = [
        result("c_1", "connect_calendar", loaded: ["calendar/list_events"], error: "Calendar is down"),
        result("c_2", "connect_calendar", loaded: ["archived_tool"]),
      ]

      expect(gateway.wrap_messages(messages, deferred)).must_equal messages
    end

    it "returns the same bytes on every call" do
      messages = [
        Riffer::Messages::User.new("What's on?"),
        Riffer::Messages::Assistant.new("", tool_calls: [tool_call("connect_calendar", "c_1")]),
        result("c_1", "connect_calendar", loaded: ["calendar/list_events"]),
        Riffer::Messages::Assistant.new("", tool_calls: [tool_call("calendar/list_events", "c_2", '{"date":"x"}')]),
        result("c_2", "calendar/list_events", content: "3 events"),
      ]

      expect(gateway.wrap_messages(messages, deferred).map(&:to_h)).
        must_equal gateway.wrap_messages(messages, deferred).map(&:to_h)
    end

    it "leaves the messages it is given untouched" do
      assistant = Riffer::Messages::Assistant.new("", tool_calls: [tool_call("create_event", "c_1")])
      loading = result("c_2", "connect_calendar", loaded: ["create_event"])
      before = [assistant, loading].map(&:to_h)

      gateway.wrap_messages([assistant, loading], deferred)

      expect([assistant, loading].map(&:to_h)).must_equal before
    end

    it "returns the same messages without a deferred tool to carry" do
      messages = [Riffer::Messages::Assistant.new("", tool_calls: [tool_call("create_event", "c_1")])]

      expect(gateway.wrap_messages(messages, [])).must_be_same_as messages
    end
  end

  describe ".unwrap_tool_call" do
    it "turns a gateway call into a call to the named tool with its arguments as given" do
      call = gateway_call("c_1", '{"name":"calendar/list_events","arguments":"{\"date\": \"2026-11-06\"}"}')

      expect(gateway.unwrap_tool_call(call, deferred)).
        must_equal tool_call("calendar/list_events", "c_1", '{"date": "2026-11-06"}')
    end

    it "decodes a tool's wire name" do
      call = gateway_call("c_1", '{"name":"calendar__list_events","arguments":"{}"}')

      expect(gateway.unwrap_tool_call(call, deferred).name).must_equal "calendar/list_events"
    end

    it "round-trips a call wrapped by wrap_messages" do
      original = tool_call("calendar/list_events", "c_1", '{"date":"2026-11-06"}')
      wrapped = gateway.wrap_messages([Riffer::Messages::Assistant.new("", tool_calls: [original])], deferred)

      expect(gateway.unwrap_tool_call(wrapped.first.tool_calls.first, deferred)).must_equal original
    end

    it "leaves a call to any other tool alone" do
      call = tool_call("get_weather", "c_1")

      expect(gateway.unwrap_tool_call(call, deferred)).must_be_same_as call
    end

    [
      "not json",
      "",
      "[]",
      '{"name":"create_event"}',
      '{"name":"create_event","arguments":{"date":"x"}}',
      '{"name":42,"arguments":"{}"}',
      '{"name":"missing","arguments":"{"}',
      '{"name":"get_weather","arguments":"{}"}',
    ].each do |arguments|
      it "leaves a gateway call with arguments #{arguments.inspect} as a gateway call" do
        call = gateway_call("c_1", arguments)

        expect(gateway.unwrap_tool_call(call, deferred)).must_be_same_as call
      end
    end
  end

  describe ".unwrap_parts" do
    it "unwraps gateway calls and keeps every other part in order" do
      parts = [
        Riffer::Messages::Assistant::TextPart.new("Sure"),
        gateway_call("c_1", '{"name":"create_event","arguments":"{}"}'),
        tool_call("get_weather", "c_2"),
      ]

      expect(gateway.unwrap_parts(parts, deferred)).must_equal [parts[0], tool_call("create_event", "c_1"), parts[2]]
    end

    it "returns the parts unchanged without a deferred tool to carry" do
      parts = [gateway_call("c_1", '{"name":"create_event","arguments":"{}"}')]

      expect(gateway.unwrap_parts(parts, [])).must_be_same_as parts
    end
  end

  describe "Sink" do
    let(:events) { [] }
    let(:sink) { gateway.unwrapping_sink(events, deferred) }

    def delta(id, name, fragment)
      Riffer::StreamEvents::ToolCallDelta.new(item_id: id, name: name, arguments_delta: fragment)
    end

    def done(id, name, arguments)
      Riffer::StreamEvents::ToolCallDone.new(item_id: id, call_id: id, name: name, arguments: arguments)
    end

    it "drops a gateway call's deltas, including ones that don't repeat its name" do
      sink << delta("c_1", gateway_name, '{"name":')
      sink << delta("c_1", nil, '"create_event"}')
      sink << delta("c_2", "get_weather", "{}")

      expect(events.map(&:to_h)).must_equal [delta("c_2", "get_weather", "{}").to_h]
    end

    it "unwraps a finished gateway call" do
      sink << done("c_1", gateway_name, '{"name":"calendar__list_events","arguments":"{\"date\":\"x\"}"}')

      expect(events.map(&:to_h)).must_equal [done("c_1", "calendar/list_events", '{"date":"x"}').to_h]
    end

    it "passes on a malformed gateway call and every other event as they are" do
      malformed = done("c_1", gateway_name, "{}")
      text = Riffer::StreamEvents::TextDelta.new("Hi")
      sink << malformed
      sink << text

      expect(events).must_equal [malformed, text]
    end

    it "is the sink itself without a deferred tool to carry" do
      expect(gateway.unwrapping_sink(events, [])).must_be_same_as events
    end
  end
end
