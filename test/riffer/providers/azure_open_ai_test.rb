# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::AzureOpenAI do
  let(:api_key) { ENV.fetch("AZURE_OPENAI_API_KEY", "test_api_key") }
  let(:endpoint) { ENV.fetch("AZURE_OPENAI_ENDPOINT", "https://test.openai.azure.com/") }

  # Credentials now reach the provider only through config, so every test that
  # builds a client needs them configured.
  before do
    Riffer.config.azure_openai.api_key = api_key
    Riffer.config.azure_openai.endpoint = endpoint
  end

  after do
    Riffer.config.azure_openai.api_key = nil
    Riffer.config.azure_openai.endpoint = nil
    Riffer.config.azure_openai.client = nil
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::AzureOpenAI.semconv_provider_name).must_equal "azure.ai.openai"
    end
  end

  describe "#initialize" do
    it "creates the provider" do
      provider = Riffer::Providers::AzureOpenAI.new

      expect(provider).must_be_instance_of Riffer::Providers::AzureOpenAI
    end

    it "is a subclass of OpenAI provider" do
      provider = Riffer::Providers::AzureOpenAI.new

      expect(provider).must_be_kind_of Riffer::Providers::OpenAI
    end

    it "takes no arguments" do
      expect { Riffer::Providers::AzureOpenAI.new(endpoint: endpoint) }.must_raise ArgumentError
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::AzureOpenAI.new(base_url: endpoint) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "uses the configured client" do
      configured = Object.new
      Riffer.config.azure_openai.client = configured

      expect(Riffer::Providers::AzureOpenAI.new.send(:client)).must_be_same_as configured
    end

    it "ignores a client configured for the plain OpenAI provider" do
      Riffer.config.openai.client = Object.new

      expect(Riffer::Providers::AzureOpenAI.new.send(:client)).must_be_instance_of OpenAI::Client
    ensure
      Riffer.config.openai.client = nil
    end

    it "ignores credentials configured for the plain OpenAI provider" do
      Riffer.config.openai.base_url = "https://gateway.example/v1"

      expect(Riffer::Providers::AzureOpenAI.new.send(:client).base_url.to_s).must_equal endpoint
    ensure
      Riffer.config.openai.base_url = nil
    end

    it "memoizes the client it builds" do
      provider = Riffer::Providers::AzureOpenAI.new

      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    # Guards the deliberate non-compacting in build_client: borrowing the
    # OpenAI SDK must never route Azure traffic, or an OpenAI credential, to
    # whatever OPENAI_API_KEY / OPENAI_BASE_URL name.
    it "never falls back to OPENAI_API_KEY or OPENAI_BASE_URL" do
      originals = ENV.to_hash.slice("OPENAI_API_KEY", "OPENAI_BASE_URL", "AZURE_OPENAI_API_KEY")
      ENV["OPENAI_API_KEY"] = "sk-openai-secret"
      ENV["OPENAI_BASE_URL"] = "https://gateway.example/v1"
      ENV["AZURE_OPENAI_API_KEY"] = nil
      Riffer.config.azure_openai.api_key = nil

      expect { Riffer::Providers::AzureOpenAI.new.send(:client) }.must_raise ArgumentError
    ensure
      %w[OPENAI_API_KEY OPENAI_BASE_URL AZURE_OPENAI_API_KEY].each { |k| ENV[k] = originals[k] }
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AzureOpenAI/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AzureOpenAI/_generate_text/when_system_and_prompt_are_provided/" \
          "returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AzureOpenAI.new
          params = { system: "Be concise", prompt: "Say hello", model: "gpt-5-mini" }
          result = provider.generate_text(**params)

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AzureOpenAI/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AzureOpenAI.new
          messages = [
            { role: "system", content: "Be concise" },
            { role: "user", content: "Say hello" },
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-mini")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AzureOpenAI.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-mini",
            structured_output: structured_output,
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns valid JSON with expected keys" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AzureOpenAI.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-mini",
            structured_output: structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed.key?("sentiment")).must_equal true
        end
      end
    end
  end

  describe "tags" do
    it "inherits the OpenAI mapping: tags to metadata and user_id to safety_identifier" do
      provider = Riffer::Providers::AzureOpenAI.new
      messages = [Riffer::Messages::User.new("Hello")]
      params = provider.send(
        :build_request_params,
        messages,
        "gpt-5-mini",
        { tags: { "team" => "growth", "user_id" => "u_1" } },
      )

      expect(
        [params[:metadata],
         params[:safety_identifier],],
      ).must_equal([{ "team" => "growth", "user_id" => "u_1" }, "u_1"])
    end
  end

  # Currently unable to access azure, keeping commented out for now.
  # describe "per-call tags (end-to-end)" do
  #   it "forwards per-call tags to the request" do
  #     provider = Riffer::Providers::AzureOpenAI.new
  #     VCR.use_cassette("Riffer_Providers_AzureOpenAI/tags/forwards_metadata_and_safety_identifier") do
  #       result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini",
  #                                       tags: {"user_id" => "u_1", "team" => "growth"})
  #       expect(result).must_be_instance_of Riffer::Messages::Assistant
  #     end
  #   end
  # end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini")

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AzureOpenAI.new
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::AzureOpenAI.new
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a
          deltas = events.grep(Riffer::StreamEvents::TextDelta)

          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::AzureOpenAI.new
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
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-mini",
            tools: [weather_tool],
          )

          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-mini",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::AzureOpenAI.new
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gpt-5-mini",
            tools: [weather_tool],
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
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")

          expect(result.token_usage).wont_be_nil
        end
      end

      it "includes input_tokens" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")

          expect(result.token_usage.input_tokens).must_be :>, 0
        end
      end

      it "includes output_tokens" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AzureOpenAI.new
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-mini")

          expect(result.token_usage.output_tokens).must_be :>, 0
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event" do
        VCR.use_cassette("Riffer_Providers_AzureOpenAI/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::AzureOpenAI.new
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-mini").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done).wont_be_nil
        end
      end
    end
  end
end
