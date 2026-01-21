# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Test do
  let(:provider) { Riffer::Providers::Test.new }

  describe "#initialize" do
    it "initializes calls to empty array" do
      expect(provider.calls).must_equal []
    end
  end

  describe "#stub_response" do
    it "sets a stubbed response with content" do
      provider.stub_response("Hello from the machine!")
      result = provider.generate_text(prompt: "Hi")
      expect(result).must_be_instance_of Riffer::Messages::Assistant
    end

    it "sets the content of the stubbed response" do
      provider.stub_response("Hello from the machine!")
      result = provider.generate_text(prompt: "Hi")
      expect(result.content).must_equal "Hello from the machine!"
    end
  end

  describe "#generate_text" do
    it "returns an Assistant message when no stubbed response" do
      result = provider.generate_text(prompt: "Hello")
      expect(result).must_be_instance_of Riffer::Messages::Assistant
    end

    it "returns default content when no stubbed response" do
      result = provider.generate_text(prompt: "Hello")
      expect(result.content).must_equal "Test response"
    end

    it "stores normalized messages in calls" do
      provider.generate_text(prompt: "Hello")
      expect(provider.calls.last[:messages]).must_equal [{role: "user", content: "Hello"}]
    end

    it "stores system and user messages in calls when both provided" do
      provider.generate_text(prompt: "Hello", system: "You are helpful")
      expect(provider.calls.last[:messages]).must_equal [
        {role: "system", content: "You are helpful"},
        {role: "user", content: "Hello"}
      ]
    end

    it "stores model parameter in calls" do
      provider.generate_text(prompt: "Hello", model: "test-model")
      expect(provider.calls.last[:model]).must_equal "test-model"
    end

    it "stores reasoning parameter in calls" do
      provider.generate_text(prompt: "Hello", reasoning: "high")
      expect(provider.calls.last[:reasoning]).must_equal "high"
    end
  end

  describe "#stream_text" do
    it "returns an enumerator" do
      result = provider.stream_text(prompt: "Hello")
      expect(result).must_be_instance_of Enumerator
    end

    it "emits TextDelta events" do
      events = provider.stream_text(prompt: "Question").to_a
      text_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
      expect(text_deltas.size).must_be :>, 0
    end

    it "emits TextDone event" do
      events = provider.stream_text(prompt: "Question").to_a
      text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
      expect(text_done).wont_be_nil
    end

    it "stores options in calls" do
      provider.stream_text(prompt: "Hello", reasoning: "high").to_a
      expect(provider.calls.last[:reasoning]).must_equal "high"
    end
  end

  describe "tool calling" do
    describe "#stub_response with tool_calls" do
      it "formats tool_calls with generated id" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls.first[:id]).must_equal "test_id_0"
      end

      it "formats tool_calls with generated call_id" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls.first[:call_id]).must_equal "test_call_0"
      end

      it "preserves the tool name" do
        provider.stub_response("", tool_calls: [{name: "weather_lookup", arguments: "{}"}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls.first[:name]).must_equal "weather_lookup"
      end

      it "preserves string arguments" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"city":"Toronto"}'}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls.first[:arguments]).must_equal '{"city":"Toronto"}'
      end

      it "converts hash arguments to JSON" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: {city: "Toronto"}}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls.first[:arguments]).must_equal '{"city":"Toronto"}'
      end

      it "uses provided id if specified" do
        provider.stub_response("", tool_calls: [{id: "custom_id", name: "my_tool", arguments: "{}"}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls.first[:id]).must_equal "custom_id"
      end

      it "handles multiple tool calls count" do
        provider.stub_response("", tool_calls: [
          {name: "tool_a", arguments: "{}"},
          {name: "tool_b", arguments: "{}"}
        ])
        result = provider.generate_text(prompt: "Call tools")
        expect(result.tool_calls.length).must_equal 2
      end

      it "handles multiple tool calls first name" do
        provider.stub_response("", tool_calls: [
          {name: "tool_a", arguments: "{}"},
          {name: "tool_b", arguments: "{}"}
        ])
        result = provider.generate_text(prompt: "Call tools")
        expect(result.tool_calls[0][:name]).must_equal "tool_a"
      end

      it "handles multiple tool calls second name" do
        provider.stub_response("", tool_calls: [
          {name: "tool_a", arguments: "{}"},
          {name: "tool_b", arguments: "{}"}
        ])
        result = provider.generate_text(prompt: "Call tools")
        expect(result.tool_calls[1][:name]).must_equal "tool_b"
      end
    end

    describe "#generate_text with tool_calls" do
      it "returns Assistant message" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: "{}"}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result).must_be_instance_of Riffer::Messages::Assistant
      end

      it "returns message with tool_calls" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: "{}"}])
        result = provider.generate_text(prompt: "Call a tool")
        expect(result.tool_calls).wont_be_empty
      end

      it "stores tools parameter in calls" do
        tool_class = Class.new(Riffer::Tool) do
          identifier "test_tool"
          description "A test tool"
        end
        provider.generate_text(prompt: "Hello", tools: [tool_class])
        expect(provider.calls.last[:tools]).must_equal [tool_class]
      end
    end

    describe "#stream_text with tool_calls" do
      it "emits ToolCallDelta events" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
        events = provider.stream_text(prompt: "Call a tool").to_a
        tool_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDelta) }
        expect(tool_deltas).wont_be_empty
      end

      it "emits ToolCallDone events" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
        events = provider.stream_text(prompt: "Call a tool").to_a
        tool_done = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
        expect(tool_done).wont_be_empty
      end

      it "includes tool name in ToolCallDelta" do
        provider.stub_response("", tool_calls: [{name: "weather_lookup", arguments: "{}"}])
        events = provider.stream_text(prompt: "Call a tool").to_a
        tool_delta = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDelta) }
        expect(tool_delta.name).must_equal "weather_lookup"
      end

      it "includes complete arguments in ToolCallDone" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"city":"Toronto"}'}])
        events = provider.stream_text(prompt: "Call a tool").to_a
        tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
        expect(tool_done.arguments).must_equal '{"city":"Toronto"}'
      end

      it "emits events for multiple tool calls" do
        provider.stub_response("", tool_calls: [
          {name: "tool_a", arguments: "{}"},
          {name: "tool_b", arguments: "{}"}
        ])
        events = provider.stream_text(prompt: "Call tools").to_a
        tool_done_events = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
        expect(tool_done_events.length).must_equal 2
      end
    end

    describe "response queue behavior" do
      it "consumes first stubbed response" do
        provider.stub_response("First response")
        provider.stub_response("Second response")

        result = provider.generate_text(prompt: "First")
        expect(result.content).must_equal "First response"
      end

      it "consumes second stubbed response" do
        provider.stub_response("First response")
        provider.stub_response("Second response")

        provider.generate_text(prompt: "First")
        result = provider.generate_text(prompt: "Second")
        expect(result.content).must_equal "Second response"
      end

      it "returns default response when queue is empty" do
        provider.stub_response("Only response")
        provider.generate_text(prompt: "First")
        result = provider.generate_text(prompt: "Second")
        expect(result.content).must_equal "Test response"
      end

      it "first response has tool calls" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: "{}"}])
        provider.stub_response("Final answer")

        result = provider.generate_text(prompt: "Call tool")
        expect(result.tool_calls).wont_be_empty
      end

      it "second response has no tool calls" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: "{}"}])
        provider.stub_response("Final answer")

        provider.generate_text(prompt: "Call tool")
        result = provider.generate_text(prompt: "After tool")
        expect(result.tool_calls).must_be_empty
      end

      it "second response has text content" do
        provider.stub_response("", tool_calls: [{name: "my_tool", arguments: "{}"}])
        provider.stub_response("Final answer")

        provider.generate_text(prompt: "Call tool")
        result = provider.generate_text(prompt: "After tool")
        expect(result.content).must_equal "Final answer"
      end

      it "clears stubs with clear_stubs" do
        provider.stub_response("Stubbed")
        provider.clear_stubs
        result = provider.generate_text(prompt: "Hello")
        expect(result.content).must_equal "Test response"
      end
    end
  end
end
