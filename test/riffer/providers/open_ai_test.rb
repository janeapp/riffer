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

    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-nano",
            structured_output: structured_output
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns non-empty content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-nano",
            structured_output: structured_output
          )
          expect(result.content).wont_be_empty
        end
      end

      it "returns valid JSON content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-nano",
            structured_output: structured_output
          )
          JSON.parse(result.content)
        end
      end

      it "includes sentiment key" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-nano",
            structured_output: structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed.key?("sentiment")).must_equal true
        end
      end

      it "includes score key" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gpt-5-nano",
            structured_output: structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed.key?("score")).must_equal true
        end
      end
    end

    describe "structured output with nested object" do
      let(:nested_object_prompt) { "Extract the address from: John lives at 123 Main St, Toronto, ON M5V 2T6, Canada" }

      let(:nested_object_structured_output) do
        params = Riffer::Params.new
        params.required(:name, String, description: "Person name")
        params.required(:address, Hash, description: "Mailing address") do
          required :street, String, description: "Street address"
          required :city, String, description: "City"
          optional :postal_code, String, description: "Postal or zip code"
          optional :country, String, description: "Country"
        end
        Riffer::StructuredOutput.new(params)
      end

      it "returns valid JSON with nested object content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output_nested_object/returns_nested_json") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: nested_object_prompt,
            model: "gpt-5-nano",
            structured_output: nested_object_structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed["name"]).must_include "John"
          expect(parsed["address"]).must_be_instance_of Hash
          expect(parsed["address"]["street"]).must_include "123 Main"
          expect(parsed["address"]["city"]).must_include "Toronto"
        end
      end
    end

    describe "structured output with null optional fields" do
      let(:null_optional_prompt) { "Extract info from: Jane works at 42 King St in Vancouver. No other details are known. Return null for any unknown fields." }

      let(:null_optional_structured_output) do
        params = Riffer::Params.new
        params.required(:name, String, description: "Person name")
        params.required(:address, Hash, description: "Mailing address") do
          required :street, String, description: "Street address"
          required :city, String, description: "City"
          optional :postal_code, String, description: "Postal or zip code"
          optional :country, String, description: "Country"
        end
        Riffer::StructuredOutput.new(params)
      end

      it "returns null for optional fields when info is unavailable" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output_null_optionals/returns_null_for_optional_fields") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: null_optional_prompt,
            model: "gpt-5-nano",
            structured_output: null_optional_structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed["name"]).must_include "Jane"
          expect(parsed["address"]["street"]).must_include "42 King"
          expect(parsed["address"]["city"]).must_include "Vancouver"
          expect(parsed["address"]["postal_code"]).must_be_nil
          expect(parsed["address"]["country"]).must_be_nil
        end
      end
    end

    describe "structured output with typed array" do
      let(:typed_array_prompt) { "List 3 tags and 3 scores (0.0-1.0) for: 'Ruby is a great programming language'" }

      let(:typed_array_structured_output) do
        params = Riffer::Params.new
        params.required(:tags, Array, of: String, description: "Descriptive tags")
        params.required(:scores, Array, of: Float, description: "Relevance scores between 0 and 1")
        Riffer::StructuredOutput.new(params)
      end

      it "returns valid JSON with typed array content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output_typed_array/returns_typed_arrays") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: typed_array_prompt,
            model: "gpt-5-nano",
            structured_output: typed_array_structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed["tags"].length).must_equal 3
          expect(parsed["scores"].length).must_equal 3
          parsed["tags"].each { |tag| expect(tag).must_be_instance_of String }
          parsed["scores"].each { |score| expect(score).must_be_instance_of Float }
        end
      end
    end

    describe "structured output with array of objects" do
      let(:array_of_objects_prompt) { "List 2 items from an order: a book costing $12.99 and a pen costing $1.50" }

      let(:array_of_objects_structured_output) do
        params = Riffer::Params.new
        params.required(:order_id, String, description: "Order identifier")
        params.required(:items, Array, description: "Line items") do
          required :name, String, description: "Product name"
          required :price, Float, description: "Price in dollars"
          optional :quantity, Integer, description: "Quantity ordered"
        end
        Riffer::StructuredOutput.new(params)
      end

      it "returns valid JSON with array of objects content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/structured_output_array_of_objects/returns_array_of_objects") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(
            prompt: array_of_objects_prompt,
            model: "gpt-5-nano",
            structured_output: array_of_objects_structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed["order_id"]).must_be_instance_of String
          expect(parsed["items"].length).must_equal 2
          parsed["items"].each do |item|
            expect(item["name"]).must_be_instance_of String
            expect(item["price"]).must_be_instance_of Float
          end
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

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_OpenAI/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-nano")
          expect(result.token_usage).wont_be_nil
          expect(result.token_usage.input_tokens).must_equal 8
          expect(result.token_usage.output_tokens).must_equal 145
          expect(result.token_usage.total_tokens).must_equal 153
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event with correct token counts" do
        VCR.use_cassette("Riffer_Providers_OpenAI/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done).wont_be_nil
          expect(usage_done.token_usage.input_tokens).must_equal 8
          expect(usage_done.token_usage.output_tokens).must_equal 213
          expect(usage_done.token_usage.total_tokens).must_equal 221
        end
      end

      it "yields TokenUsageDone after TextDone" do
        VCR.use_cassette("Riffer_Providers_OpenAI/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          text_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          usage_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done_index).must_be :>, text_done_index
        end
      end
    end
  end

  describe "structured output" do
    it "includes text.format in request params" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})

      expect(params[:text][:format][:type]).must_equal "json_schema"
    end

    it "sets schema name to response" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})

      expect(params[:text][:format][:name]).must_equal "response"
    end

    it "sets strict to true" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})

      expect(params[:text][:format][:strict]).must_equal true
    end

    it "includes json_schema in format" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})

      expect(params[:text][:format][:schema][:type]).must_equal "object"
    end

    it "does not include text.format when not configured" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "gpt-5-nano", {})

      expect(params[:text]).must_be_nil
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})

      expect(params.key?(:structured_output)).must_equal false
    end

    it "puts all properties in required for strict mode" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      p = Riffer::Params.new
      p.required(:name, String)
      p.optional(:age, Integer)
      structured_output = Riffer::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})
      schema = result[:text][:format][:schema]

      expect(schema[:required]).must_equal ["name", "age"]
    end

    it "makes optional properties nullable for strict mode" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      p = Riffer::Params.new
      p.required(:name, String)
      p.optional(:age, Integer)
      structured_output = Riffer::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})
      schema = result[:text][:format][:schema]

      expect(schema[:properties]["name"][:type]).must_equal "string"
      expect(schema[:properties]["age"][:type]).must_equal ["integer", "null"]
    end

    it "makes nested optional properties nullable for strict mode" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      p = Riffer::Params.new
      p.required(:address, Hash) do
        required :city, String
        optional :zip, String
      end
      structured_output = Riffer::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})
      address = result[:text][:format][:schema][:properties]["address"]

      expect(address[:required]).must_equal ["city", "zip"]
      expect(address[:properties]["city"][:type]).must_equal "string"
      expect(address[:properties]["zip"][:type]).must_equal ["string", "null"]
    end

    it "makes optional properties in array items nullable for strict mode" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      p = Riffer::Params.new
      p.required(:items, Array) do
        required :sku, String
        optional :notes, String
      end
      structured_output = Riffer::StructuredOutput.new(p)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(:build_request_params, messages, "gpt-5-nano", {structured_output: structured_output})
      items_schema = result[:text][:format][:schema][:properties]["items"][:items]

      expect(items_schema[:required]).must_equal ["sku", "notes"]
      expect(items_schema[:properties]["sku"][:type]).must_equal "string"
      expect(items_schema[:properties]["notes"][:type]).must_equal ["string", "null"]
    end

    it "validates successfully when nullable optional fields return null" do
      p = Riffer::Params.new
      p.required(:name, String)
      p.optional(:age, Integer)
      p.required(:address, Hash) do
        required :city, String
        optional :zip, String
      end
      structured_output = Riffer::StructuredOutput.new(p)

      result = structured_output.parse_and_validate('{"name":"John","age":null,"address":{"city":"Toronto","zip":null}}')

      expect(result.success?).must_equal true
      expect(result.object[:name]).must_equal "John"
      expect(result.object[:age]).must_be_nil
      expect(result.object[:address][:city]).must_equal "Toronto"
      expect(result.object[:address][:zip]).must_be_nil
    end
  end

  describe "web search" do
    describe "#generate_text with web_search" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_generate_text/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: true)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "accepts hash web_search options" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_generate_text/accepts_hash_web_search_options") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: {search_context_size: "medium"})
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "#stream_text with web_search" do
      it "yields WebSearchStatus events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_stream_text/yields_web_search_status") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: true).to_a
          web_search_statuses = events.select { |e| e.is_a?(Riffer::StreamEvents::WebSearchStatus) }
          expect(web_search_statuses).wont_be_empty
        end
      end

      it "yields WebSearchDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_stream_text/yields_web_search_result") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: true).to_a
          web_search_result = events.find { |e| e.is_a?(Riffer::StreamEvents::WebSearchDone) }
          expect(web_search_result).wont_be_nil
        end
      end

      it "includes query in WebSearchDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_stream_text/yields_web_search_result") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: true).to_a
          web_search_result = events.find { |e| e.is_a?(Riffer::StreamEvents::WebSearchDone) }
          expect(web_search_result.query).wont_be_empty
        end
      end

      it "includes sources array in WebSearchDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_stream_text/yields_web_search_result") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: true).to_a
          web_search_result = events.find { |e| e.is_a?(Riffer::StreamEvents::WebSearchDone) }
          expect(web_search_result.sources).must_be_instance_of Array
        end
      end

      it "yields web search events before text events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/web_search/_stream_text/yields_web_search_before_text") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "gpt-5-nano", web_search: true).to_a
          first_web_search_index = events.index { |e| e.is_a?(Riffer::StreamEvents::WebSearchStatus) }
          first_text_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }

          if first_web_search_index && first_text_index
            expect(first_web_search_index).must_be :<, first_text_index
          end
        end
      end
    end
  end

  describe "file handling" do
    let(:image_base64) { "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg==" }

    describe "#generate_text with image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gpt-5-nano", files: [file])
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gpt-5-nano", files: [file])
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#generate_text with document" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_generate_text/with_document") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          result = provider.generate_text(prompt: "What is in this document?", model: "gpt-5-nano", files: [file])
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_generate_text/with_document") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          result = provider.generate_text(prompt: "What is in this document?", model: "gpt-5-nano", files: [file])
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with document" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_stream_text/with_document") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          events = provider.stream_text(prompt: "What is in this document?", model: "gpt-5-nano", files: [file]).to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_stream_text/with_document") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          events = provider.stream_text(prompt: "What is in this document?", model: "gpt-5-nano", files: [file]).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end

    describe "#stream_text with image" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_stream_text/with_image") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          events = provider.stream_text(prompt: "Describe this image", model: "gpt-5-nano", files: [file]).to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/file_handling/_stream_text/with_image") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          events = provider.stream_text(prompt: "Describe this image", model: "gpt-5-nano", files: [file]).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end
  end

  describe "tool schema strict mode" do
    it "applies strict_schema to tool parameters" do
      tool = Class.new(Riffer::Tool) do
        identifier "test_tool"
        description "A test tool"
        params do
          required :name, String
          optional :age, Integer
        end
      end

      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      format = provider.send(:convert_tool_to_openai_format, tool)
      schema = format[:parameters]

      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["age"][:type]).must_equal ["integer", "null"]
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
          expect(result.tool_calls.first.name).must_equal "get_weather"
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
          args = JSON.parse(result.tool_calls.first.arguments)
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
          expect(result.tool_calls.first.id).wont_be_nil
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
          expect(result.tool_calls.first.call_id).wont_be_nil
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
              Riffer::Messages::Assistant::ToolCall.new(id: "fc_tool_call_123", call_id: "call_tool_123", name: "get_weather", arguments: '{"city":"Toronto"}')
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
              Riffer::Messages::Assistant::ToolCall.new(id: "fc_tool_call_123", call_id: "call_tool_123", name: "get_weather", arguments: '{"city":"Toronto"}')
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
