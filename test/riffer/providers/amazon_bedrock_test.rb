# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::AmazonBedrock do
  let(:api_token) { ENV.fetch("AWS_BEDROCK_API_TOKEN", "test_api_token") }

  describe "#initialize" do
    it "creates Bedrock client with an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      expect(provider).must_be_instance_of Riffer::Providers::AmazonBedrock
    end

    it "sets the region correctly with an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      client = provider.instance_variable_get(:@client)
      assert_equal "us-east-1", client.config.region
    end

    it "accepts additional options with an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1", retry_limit: 60)
      client = provider.instance_variable_get(:@client)
      assert_equal 60, client.config.retry_limit
    end

    it "creates Bedrock client without an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(region: "us-east-1")
      expect(provider).must_be_instance_of Riffer::Providers::AmazonBedrock
    end

    it "sets the region correctly without an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(region: "us-east-1")
      client = provider.instance_variable_get(:@client)
      assert_equal "us-east-1", client.config.region
    end

    it "accepts additional options without an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(region: "us-east-1", retry_limit: 60)
      client = provider.instance_variable_get(:@client)
      assert_equal 60, client.config.retry_limit
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = {system: "Be concise", prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0"}
          result = provider.generate_text(**params)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            {role: "system", content: "Be concise"},
            {role: "user", content: "Say hello"}
          ]
          result = provider.generate_text(messages: messages, model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello")
          ]
          result = provider.generate_text(messages: messages, model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/with_an_Assistant_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?")
          ]
          result = provider.generate_text(messages: messages, model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end
    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns non-empty content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output
          )
          expect(result.content).wont_be_empty
        end
      end

      it "returns valid JSON content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output
          )
          JSON.parse(result.content)
        end
      end

      it "includes sentiment key" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed.key?("sentiment")).must_equal true
        end
      end

      it "includes score key" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed.key?("score")).must_equal true
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.stream_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0").to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0").to_a
          deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "anthropic.claude-3-haiku-20240307-v1:0"
          )
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "anthropic.claude-3-haiku-20240307-v1:0"
          ).to_a
          expect(events).wont_be_empty
        end
      end
    end
  end

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0")
          expect(result.token_usage).wont_be_nil
          expect(result.token_usage.input_tokens).must_equal 9
          expect(result.token_usage.output_tokens).must_equal 5
          expect(result.token_usage.total_tokens).must_equal 14
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event with correct token counts" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done).wont_be_nil
          expect(usage_done.token_usage.input_tokens).must_equal 9
          expect(usage_done.token_usage.output_tokens).must_equal 5
          expect(usage_done.token_usage.total_tokens).must_equal 14
        end
      end

      it "yields TokenUsageDone after TextDone" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "anthropic.claude-3-haiku-20240307-v1:0").to_a
          text_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          usage_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done_index).must_be :>, text_done_index
        end
      end
    end
  end

  describe "structured output" do
    it "includes output_config.text_format in request params" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "anthropic.claude-3-haiku-20240307-v1:0", {structured_output: structured_output})

      expect(params[:output_config][:text_format][:type]).must_equal "json_schema"
    end

    it "includes json_schema structure with name" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "anthropic.claude-3-haiku-20240307-v1:0", {structured_output: structured_output})

      expect(params[:output_config][:text_format][:structure][:json_schema][:name]).must_equal "response"
    end

    it "serializes schema as JSON string" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "anthropic.claude-3-haiku-20240307-v1:0", {structured_output: structured_output})

      schema_json = params[:output_config][:text_format][:structure][:json_schema][:schema]
      expect(schema_json).must_be_instance_of String
      parsed = JSON.parse(schema_json)
      expect(parsed["type"]).must_equal "object"
    end

    it "does not include output_config when not configured" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "anthropic.claude-3-haiku-20240307-v1:0", {})

      expect(params.key?(:output_config)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "anthropic.claude-3-haiku-20240307-v1:0", {structured_output: structured_output})

      expect(params.key?(:structured_output)).must_equal false
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
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/parses_arguments") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          args = JSON.parse(result.tool_calls.first.arguments)
          expect(args["city"]).must_equal "Toronto"
        end
      end

      it "includes tool call id" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/includes_ids") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first.id).wont_be_nil
        end
      end
    end

    describe "#generate_text with Tool message in history" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              Riffer::Messages::Assistant::ToolCall.new(id: "tooluse_123", call_id: "tooluse_123", name: "get_weather", arguments: '{"city":"Toronto"}')
            ]),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "tooluse_123", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              Riffer::Messages::Assistant::ToolCall.new(id: "tooluse_123", call_id: "tooluse_123", name: "get_weather", arguments: '{"city":"Toronto"}')
            ]),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "tooluse_123", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#generate_text with multiple Tool messages" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_multiple_tool_messages") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto and Vancouver?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              Riffer::Messages::Assistant::ToolCall.new(id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M", call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M", name: "get_weather", arguments: '{"city":"Toronto"}'),
              Riffer::Messages::Assistant::ToolCall.new(id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ", call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ", name: "get_weather", arguments: '{"city":"Vancouver"}')
            ]),
            Riffer::Messages::Tool.new("Toronto: 15°C", tool_call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M", name: "get_weather"),
            Riffer::Messages::Tool.new("Vancouver: 12°C", tool_call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_multiple_tool_messages") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto and Vancouver?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              Riffer::Messages::Assistant::ToolCall.new(id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M", call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M", name: "get_weather", arguments: '{"city":"Toronto"}'),
              Riffer::Messages::Assistant::ToolCall.new(id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ", call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ", name: "get_weather", arguments: '{"city":"Vancouver"}')
            ]),
            Riffer::Messages::Tool.new("Toronto: 15°C", tool_call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M", name: "get_weather"),
            Riffer::Messages::Tool.new("Vancouver: 12°C", tool_call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          )
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDelta events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_stream_text/yields_tool_call_delta") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          ).to_a
          tool_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDelta) }
          expect(tool_deltas).wont_be_empty
        end
      end

      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done).wont_be_nil
        end
      end

      it "includes tool name in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_stream_text/tool_call_done_has_name") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done.name).must_equal "get_weather"
        end
      end

      it "includes arguments in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_stream_text/tool_call_done_has_arguments") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "anthropic.claude-3-haiku-20240307-v1:0",
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
