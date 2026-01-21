# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::OpenAI do
  let(:api_key) { ENV.fetch("OPENAI_API_KEY", "test_api_key") }

  describe "#initialize" do
    it "creates OpenAI client with api_key" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      expect(provider).must_be_instance_of Riffer::Providers::OpenAI
    end

    it "accepts additional options" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key, organization: "org-123")
      expect(provider).must_be_instance_of Riffer::Providers::OpenAI
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = {system: "Be concise", prompt: "Say hello", model: "gpt-5-nano"}
          result = provider.generate_text(**params)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            {role: "system", content: "Be concise"},
            {role: "user", content: "Say hello"}
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello")
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_an_Assistant_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?")
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with reasoning parameter" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_reasoning_parameter/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "What is 2+2?", model: "gpt-5-nano", reasoning: "medium")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "without reasoning parameter" do
      it "does not include reasoning in request params" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/without_reasoning_parameter/does_not_include_reasoning") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano")
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "gpt-5-nano"
          )
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "gpt-5-nano"
          ).to_a
          expect(events).wont_be_empty
        end
      end
    end

    describe "with reasoning parameter" do
      it "yields ReasoningDelta events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/with_reasoning_parameter/yields_ReasoningDelta_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is 2+2?", model: "gpt-5-nano", reasoning: "medium").to_a
          reasoning_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ReasoningDelta) }
          expect(reasoning_deltas).wont_be_empty
        end
      end

      it "yields ReasoningDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/with_reasoning_parameter/yields_ReasoningDone_event") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is 2+2?", model: "gpt-5-nano", reasoning: "medium").to_a
          reasoning_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ReasoningDone) }
          expect(reasoning_done).wont_be_nil
        end
      end

      it "yields reasoning events before text events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/with_reasoning_parameter/yields_reasoning_before_text") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is 2+2?", model: "gpt-5-nano", reasoning: "medium").to_a
          first_reasoning_index = events.index { |e| e.is_a?(Riffer::StreamEvents::ReasoningDelta) }
          first_text_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }

          if first_reasoning_index && first_text_index
            expect(first_reasoning_index).must_be :<, first_text_index
          end
        end
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
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first[:name]).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/parses_arguments") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          args = JSON.parse(result.tool_calls.first[:arguments])
          expect(args["city"]).must_equal "Toronto"
        end
      end

      it "includes tool call id" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/includes_ids") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first[:id]).wont_be_nil
        end
      end

      it "includes tool call call_id" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/includes_ids") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first[:call_id]).wont_be_nil
        end
      end
    end

    describe "#generate_text with Tool message in history" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              {id: "fc_tool_call_123", call_id: "call_tool_123", name: "get_weather", arguments: '{"city":"Toronto"}'}
            ]),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "call_tool_123", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              {id: "fc_tool_call_123", call_id: "call_tool_123", name: "get_weather", arguments: '{"city":"Toronto"}'}
            ]),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "call_tool_123", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "gpt-5-nano",
            tools: [weather_tool]
          )
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDelta events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_stream_text/yields_tool_call_delta") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          ).to_a
          tool_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDelta) }
          expect(tool_deltas).wont_be_empty
        end
      end

      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done).wont_be_nil
        end
      end

      it "includes tool name in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_stream_text/tool_call_done_has_name") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done.name).must_equal "get_weather"
        end
      end

      it "includes arguments in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_OpenAI/tool_calling/_stream_text/tool_call_done_has_arguments") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-nano",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          args = JSON.parse(tool_done.arguments)
          expect(args["city"]).must_equal "Toronto"
        end
      end
    end
  end
end
