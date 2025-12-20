# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/DescribeClass
RSpec.describe "Tool Integration" do
  # Define a test tool
  let(:weather_tool_class) do
    Class.new(Riffer::Tools::Base) do
      id "get_weather"
      description "Get the current weather in a given location"
      parameters({
        type: "object",
        properties: {
          location: {type: "string", description: "The city and state, e.g. San Francisco, CA"},
          unit: {type: "string", enum: ["celsius", "fahrenheit"]}
        },
        required: ["location"]
      })

      def execute(location:, unit: "celsius")
        "Weather in #{location}: 72°#{(unit == "celsius") ? "C" : "F"}, sunny"
      end
    end
  end

  let(:agent_class) do
    tool_class = weather_tool_class
    Class.new(Riffer::Agents::Base) do
      model "test/gpt-4o"
      instructions "You are a helpful assistant."
      tool tool_class
    end
  end

  describe "Tool Registration" do
    it "registers tools at class level" do
      expect(agent_class.tools).to include(weather_tool_class)
    end

    it "initializes tool instances" do
      agent = agent_class.new
      expect(agent.tools).to all(be_a(Riffer::Tools::Base))
      expect(agent.tools.first.class).to eq(weather_tool_class)
    end
  end

  describe "Tool Execution" do
    it "executes a tool call and returns result" do
      agent = agent_class.new

      # Stub the provider to return a tool call
      provider = agent.send(:provider_instance)
      provider.stub_response("", tool_calls: [
        {
          id: "call_123",
          name: "get_weather",
          arguments: {"location" => "San Francisco, CA"}
        }
      ])

      # Second response after tool execution
      provider.stub_response("The weather is nice!")

      agent.generate("What's the weather?")

      # Check that tool message was added
      tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages).not_to be_empty
      expect(tool_messages.first.content).to include("Weather in San Francisco, CA")
    end

    it "handles tool not found error" do
      agent = agent_class.new

      provider = agent.send(:provider_instance)
      provider.stub_response("", tool_calls: [
        {
          id: "call_123",
          name: "unknown_tool",
          arguments: {}
        }
      ])

      provider.stub_response("I couldn't complete that.")

      agent.generate("Do something")

      tool_messages = agent.messages.select { |m| m.is_a?(Riffer::Messages::Tool) }
      expect(tool_messages.first.content).to include("Tool 'unknown_tool' not found")
    end
  end

  describe "Test Provider Tool Support" do
    it "logs tool calls" do
      agent = agent_class.new
      provider = agent.send(:provider_instance)

      provider.stub_response("", tool_calls: [
        {
          id: "call_123",
          name: "get_weather",
          arguments: {"location" => "NYC"}
        }
      ])

      provider.stub_response("Done")

      agent.generate("Test")

      expect(provider.tool_calls_log).not_to be_empty
      expect(provider.tool_calls_log.first[:name]).to eq("get_weather")
    end

    it "includes tools in provider calls" do
      agent = agent_class.new
      provider = agent.send(:provider_instance)

      agent.generate("Test")

      expect(provider.calls.first[:tools]).not_to be_empty
      expect(provider.calls.first[:tools].first[:name]).to eq("get_weather")
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/DescribeClass
