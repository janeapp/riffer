# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::AzureOpenAI do
  let(:api_key) { ENV.fetch("AZURE_OPENAI_API_KEY", "test_api_key") }
  let(:endpoint) { ENV.fetch("AZURE_OPENAI_ENDPOINT", "https://test.openai.azure.com") }

  describe "#initialize" do
    it "creates Azure OpenAI client with api_key and endpoint" do
      provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
      expect(provider).must_be_instance_of Riffer::Providers::AzureOpenAI
    end

    it "is a subclass of OpenAI provider" do
      provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
      expect(provider).must_be_kind_of Riffer::Providers::OpenAI
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          params = {system: "Be concise", prompt: "Say hello", model: "gpt-5-mini"}
          result = provider.generate_text(**params)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          messages = [
            {role: "system", content: "Be concise"},
            {role: "user", content: "Say hello"}
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-mini")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-mini",
            structured_output: structured_output
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns valid JSON with expected keys" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-mini",
            structured_output: structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed.key?("sentiment")).must_equal true
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini")
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a
          deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
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
      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-mini",
            tools: [weather_tool]
          )
          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-mini",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-mini",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done).wont_be_nil
        end
      end
    end
  end

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")
          expect(result.token_usage).wont_be_nil
        end
      end

      it "includes input_tokens" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")
          expect(result.token_usage.input_tokens).must_be :>, 0
        end
      end

      it "includes output_tokens" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")
          expect(result.token_usage.output_tokens).must_be :>, 0
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::AzureOpenAI.new(api_key: api_key, base_url: endpoint)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done).wont_be_nil
        end
      end
    end
  end
end
