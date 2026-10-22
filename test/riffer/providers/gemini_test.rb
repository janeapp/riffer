# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Gemini do
  let(:api_key) { ENV.fetch("GEMINI_API_KEY", "test_api_key") }

  before { Riffer.config.gemini.api_key = api_key }

  after do
    Riffer.config.gemini.api_key = nil
    Riffer.config.gemini.client = nil
    Riffer.config.gemini.base_url = nil
  end

  def with_env(vars)
    original = vars.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::Gemini.semconv_provider_name).must_equal "gcp.gemini"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::Gemini.new }

    it "normalizes STOP to stop" do
      expect(provider.send(:build_finish_reason, "STOP", tool_calls: false).reason).must_equal :stop
    end

    it "normalizes STOP to tool_calls when the candidate carries function calls" do
      expect(provider.send(:build_finish_reason, "STOP", tool_calls: true).reason).must_equal :tool_calls
    end

    it "normalizes MAX_TOKENS to length" do
      expect(provider.send(:build_finish_reason, "MAX_TOKENS", tool_calls: false).reason).must_equal :length
    end

    it "normalizes SAFETY to content_filter" do
      expect(provider.send(:build_finish_reason, "SAFETY", tool_calls: false).reason).must_equal :content_filter
    end

    it "normalizes every safety-style value to content_filter" do
      raws = %w[RECITATION BLOCKLIST PROHIBITED_CONTENT SPII IMAGE_SAFETY IMAGE_PROHIBITED_CONTENT IMAGE_RECITATION
                LANGUAGE]
      reasons = raws.map { |raw| provider.send(:build_finish_reason, raw, tool_calls: false).reason }.uniq

      expect(reasons).must_equal [:content_filter]
    end

    it "normalizes MALFORMED_FUNCTION_CALL and UNEXPECTED_TOOL_CALL to malformed_output" do
      raws = %w[MALFORMED_FUNCTION_CALL UNEXPECTED_TOOL_CALL]
      reasons = raws.map { |raw| provider.send(:build_finish_reason, raw, tool_calls: false).reason }.uniq

      expect(reasons).must_equal [:malformed_output]
    end

    it "normalizes NO_IMAGE to error" do
      expect(provider.send(:build_finish_reason, "NO_IMAGE", tool_calls: false).reason).must_equal :error
    end

    it "normalizes catch-all values to other" do
      raws = %w[TOO_MANY_TOOL_CALLS OTHER IMAGE_OTHER FINISH_REASON_UNSPECIFIED]
      reasons = raws.map { |raw| provider.send(:build_finish_reason, raw, tool_calls: false).reason }.uniq

      expect(reasons).must_equal [:other]
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:build_finish_reason, "MYSTERY", tool_calls: false)

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "MYSTERY"]
    end

    it "returns nil without a finish reason" do
      expect(provider.send(:build_finish_reason, nil, tool_calls: false)).must_be_nil
    end

    it "extracts the finish reason when generating" do
      VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
        result = provider.generate_text(prompt: "Say hello", model: "gemini-3.5-flash-lite")

        expect(result.finish_reason).must_equal :stop
      end
    end

    it "emits a FinishReasonDone event when streaming" do
      VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
        events = provider.stream_text(prompt: "Say hello", model: "gemini-3.5-flash-lite").to_a
        done = events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }

        expect(done.finish_reason).must_equal :stop
      end
    end
  end

  describe "#initialize" do
    it "creates the provider" do
      provider = Riffer::Providers::Gemini.new

      expect(provider).must_be_instance_of Riffer::Providers::Gemini
    end

    it "takes no arguments" do
      expect { Riffer::Providers::Gemini.new(api_key: api_key) }.must_raise ArgumentError
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::Gemini.new(open_timeout: 5) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "builds a Gemini::Client from the configured api_key" do
      expect(Riffer::Providers::Gemini.new.send(:client)).must_be_instance_of Riffer::Providers::Gemini::Client
    end

    it "falls back to GEMINI_API_KEY when no api_key is configured" do
      Riffer.config.gemini.api_key = nil
      stub = stub_request(:post, /generativelanguage\.googleapis\.com/).
        with(headers: { "x-goog-api-key" => "env_key" }).
        to_return(status: 200, body: "{}")

      with_env("GEMINI_API_KEY" => "env_key") do
        Riffer::Providers::Gemini.new.send(:client).post("v1beta/x", {})
      end

      assert_requested stub
    end

    it "prefers the configured api_key over GEMINI_API_KEY" do
      Riffer.config.gemini.api_key = "config_key"
      stub = stub_request(:post, /generativelanguage\.googleapis\.com/).
        with(headers: { "x-goog-api-key" => "config_key" }).
        to_return(status: 200, body: "{}")

      with_env("GEMINI_API_KEY" => "env_key") do
        Riffer::Providers::Gemini.new.send(:client).post("v1beta/x", {})
      end

      assert_requested stub
    end

    it "uses the configured base_url" do
      Riffer.config.gemini.base_url = "http://localhost:8080"
      stub = stub_request(:post, "http://localhost:8080/v1beta/x").to_return(status: 200, body: "{}")

      Riffer::Providers::Gemini.new.send(:client).post("v1beta/x", {})

      assert_requested stub
    end

    it "raises naming both settings when no api_key is available" do
      Riffer.config.gemini.api_key = nil

      error = with_env("GEMINI_API_KEY" => nil) do
        expect { Riffer::Providers::Gemini.new.send(:client) }.must_raise Riffer::ArgumentError
      end

      expect(error.message).must_include "config.gemini.api_key"
      expect(error.message).must_include "GEMINI_API_KEY"
    end

    it "uses the configured client" do
      configured = Object.new
      Riffer.config.gemini.client = configured

      expect(Riffer::Providers::Gemini.new.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.gemini.client = -> { calls += 1 }
      provider = Riffer::Providers::Gemini.new

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      provider = Riffer::Providers::Gemini.new

      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "prefers a configured client over configured credentials" do
      configured = Object.new
      Riffer.config.gemini.client = configured

      expect(Riffer::Providers::Gemini.new.send(:client)).must_be_same_as configured
    end
  end

  describe "model validation" do
    it "raises ArgumentError for model with slashes" do
      provider = Riffer::Providers::Gemini.new

      expect do
        provider.generate_text(prompt: "Hello", model: "../admin")
      end.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError for model with spaces" do
      provider = Riffer::Providers::Gemini.new

      expect do
        provider.generate_text(prompt: "Hello", model: "gemini 2.5")
      end.must_raise Riffer::ArgumentError
    end

    it "accepts valid model names" do
      provider = Riffer::Providers::Gemini.new
      path = provider.send(:api_path, "gemini-3.5-flash-lite", "generateContent")

      expect(path).must_include "v1beta/models/gemini-3.5-flash-lite:generateContent"
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(prompt: "Say hello", model: "gemini-3.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
          params = { system: "Be concise", prompt: "Say hello", model: "gemini-3.5-flash-lite" }
          result = provider.generate_text(**params)

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
          messages = [
            { role: "system", content: "Be concise" },
            { role: "user", content: "Say hello" },
          ]
          result = provider.generate_text(messages: messages, model: "gemini-3.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::Gemini.new
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "gemini-3.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::Gemini.new
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello"),
          ]
          result = provider.generate_text(messages: messages, model: "gemini-3.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/with_an_Assistant_message/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::Gemini.new
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?"),
          ]
          result = provider.generate_text(messages: messages, model: "gemini-3.5-flash-lite")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-3.5-flash-lite",
            structured_output: structured_output,
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns non-empty content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-3.5-flash-lite",
            structured_output: structured_output,
          )

          expect(result.content).wont_be_empty
        end
      end

      it "returns valid JSON content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-3.5-flash-lite",
            structured_output: structured_output,
          )
          JSON.parse(result.content)
        end
      end

      it "includes sentiment key" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-3.5-flash-lite",
            structured_output: structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed.key?("sentiment")).must_equal true
        end
      end

      it "includes score key" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Gemini.new
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "gemini-3.5-flash-lite",
            structured_output: structured_output,
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
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns valid JSON with nested object keys" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_nested_object/returns_nested_json",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: nested_object_prompt,
            model: "gemini-3.5-flash-lite",
            structured_output: nested_object_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["name"]).must_include "John"
          expect(parsed["address"]).must_be_instance_of Hash
          expect(parsed["address"]["street"]).must_include "123 Main"
          expect(parsed["address"]["city"]).must_include "Toronto"
        end
      end
    end

    describe "structured output with typed array" do
      let(:typed_array_prompt) { "List 3 tags and 3 scores (0.0-1.0) for: 'Ruby is a great programming language'" }

      let(:typed_array_structured_output) do
        params = Riffer::Params.new
        params.required(:tags, Array, of: String, description: "Descriptive tags")
        params.required(:scores, Array, of: Float, description: "Relevance scores between 0 and 1")
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns valid JSON with typed array content" do
        VCR.use_cassette("Riffer_Providers_Gemini/_generate_text/structured_output_typed_array/returns_typed_arrays") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: typed_array_prompt,
            model: "gemini-3.5-flash-lite",
            structured_output: typed_array_structured_output,
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
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns valid JSON with array of objects content" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_array_of_objects/returns_array_of_objects",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: array_of_objects_prompt,
            model: "gemini-3.5-flash-lite",
            structured_output: array_of_objects_structured_output,
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

    describe "structured output with any_of" do
      let(:any_of_structured_output) do
        params = Riffer::Params.new
        params.required(:result, Riffer::Params::AnyOf, description: "The address, or why none was found") do
          variant do
            required :street, String, description: "Street address"
            required :city, String, description: "City"
          end
          variant do
            required :error_code, String, enum: %w[no_address multiple_addresses], description: "Why no address"
            required :error_message, String, description: "Explanation of the error"
          end
        end
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns the first variant when it applies" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_any_of/returns_first_variant",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "Extract the address from: John lives at 123 Main St, Toronto",
            model: "gemini-3.5-flash-lite",
            structured_output: any_of_structured_output,
          )
          validated = any_of_structured_output.parse_and_validate(result.content)

          expect(validated.error).must_be_nil
          expect(validated.object[:result][:street]).must_include "123 Main"
          expect(validated.object[:result][:city]).must_equal "Toronto"
        end
      end

      it "returns the second variant when the first does not apply" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_any_of/returns_second_variant",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "Extract the address from: John likes long walks by the lake",
            model: "gemini-3.5-flash-lite",
            structured_output: any_of_structured_output,
          )
          validated = any_of_structured_output.parse_and_validate(result.content)

          expect(validated.error).must_be_nil
          expect(validated.object[:result][:error_code]).must_equal "no_address"
          expect(validated.object[:result][:error_message]).must_be_instance_of String
        end
      end
    end

    describe "structured output with enum array" do
      let(:ticket_tags) { %w[urgent billing technical account] }

      let(:enum_array_structured_output) do
        params = Riffer::Params.new
        params.required(:tags, Array, of: String, enum: ticket_tags, description: "Ticket tags")
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns values from the enum" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_enum_array/returns_values_from_the_enum",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "Tag this support ticket: 'I was charged twice this month and need it fixed today.'",
            model: "gemini-3.5-flash-lite",
            structured_output: enum_array_structured_output,
          )
          validated = enum_array_structured_output.parse_and_validate(result.content)

          expect(validated.error).must_be_nil
          expect(validated.object[:tags]).must_include "billing"
        end
      end
    end

    describe "structured output with format" do
      let(:clinic_id) { "550e8400-e29b-41d4-a716-446655440000" }

      let(:format_structured_output) do
        params = Riffer::Params.new
        params.required(:visit_on, String, format: "date", description: "Visit date")
        params.required(:starts_at, String, format: "date-time", description: "Visit start, with its UTC offset")
        params.optional(:email, String, format: "email", description: "Patient email, if given")
        params.required(:clinic_ids, Array, of: String, format: "uuid", description: "Clinic IDs")
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns values in the format" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_format/returns_values_in_the_format",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "Book a visit on 2026-10-26 at 9:30am Toronto time (UTC-04:00) at clinic #{clinic_id}. " \
                    "The patient gave no email.",
            model: "gemini-3.5-flash-lite",
            structured_output: format_structured_output,
          )
          validated = format_structured_output.parse_and_validate(result.content)

          expect(validated.error).must_be_nil
          expect(validated.object[:visit_on]).must_equal "2026-10-26"
          expect(validated.object[:starts_at]).must_equal "2026-10-26T09:30:00-04:00"
          expect(validated.object[:email]).must_be_nil
          expect(validated.object[:clinic_ids]).must_equal [clinic_id]
        end
      end
    end

    describe "structured output with an array of arrays" do
      let(:nested_structured_output) do
        params = Riffer::Params.new
        params.required(:rows, Array, of: [Integer], description: "Seat numbers, one array per row")
        params.optional(:boards, Array, of: [[String]], enum: %w[x o], description: "Tic-tac-toe boards, one per game")
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns nested arrays" do
        VCR.use_cassette(
          "Riffer_Providers_Gemini/_generate_text/structured_output_array_of_arrays/returns_nested_arrays",
        ) do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "Row 1 has seats 1, 2 and 3. Row 2 has seats 4 and 5. " \
                    "Game 1's tic-tac-toe board rows are: x o x, o x o, o x x. " \
                    "Game 2's rows are: o o x, x x o, o x x.",
            model: "gemini-3.5-flash-lite",
            structured_output: nested_structured_output,
          )
          validated = nested_structured_output.parse_and_validate(result.content)

          expect(validated.error).must_be_nil
          expect(validated.object[:rows]).must_equal [[1, 2, 3], [4, 5]]
          expect(validated.object[:boards]).must_equal [
            [%w[x o x], %w[o x o], %w[o x x]],
            [%w[o o x], %w[x x o], %w[o x x]],
          ]
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
          result = provider.stream_text(prompt: "Say hello", model: "gemini-3.5-flash-lite")

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-3.5-flash-lite").to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-3.5-flash-lite").to_a
          deltas = events.grep(Riffer::StreamEvents::TextDelta)

          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-3.5-flash-lite").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
          result = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "gemini-3.5-flash-lite",
          )

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Gemini/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "gemini-3.5-flash-lite",
          ).to_a

          expect(events).wont_be_empty
        end
      end
    end
  end

  describe "structured output" do
    it "sends the JSON schema unmodified in responseFormat" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:result, Riffer::Params::AnyOf) do
        variant { required :name, String }
        variant { required :error_code, String }
      end
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result[:generationConfig]).must_equal(
        responseFormat: { text: { mimeType: "APPLICATION_JSON", schema: structured_output.json_schema } },
      )
    end

    it "does not include generationConfig when not configured" do
      provider = Riffer::Providers::Gemini.new
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", {})

      expect(result.key?(:generationConfig)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::Gemini.new
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      result = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { structured_output: structured_output },
      )

      expect(result.key?(:structured_output)).must_equal false
    end
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::Gemini.new }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }

    it "does not add a labels field (the Developer API has none)" do
      params = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.key?(:labels)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end

    it "never leaks tags into generationConfig" do
      params = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { temperature: 0.5, tags: { "team" => "growth" } },
      )

      expect(params[:generationConfig].key?(:tags)).must_equal false
    end
  end

  describe "per-call tags (end-to-end)" do
    let(:provider) { Riffer::Providers::Gemini.new }

    # Gemini drops tags, so a tagged call must match the untagged cassette's
    # request body; record: :none makes any leak fail the :body matcher.
    it "sends no tags on the wire, matching the untagged request" do
      VCR.use_cassette(
        "Riffer_Providers_Gemini/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
        record: :none,
      ) do
        result = provider.generate_text(
          prompt: "Say hello",
          model: "gemini-3.5-flash-lite",
          tags: { "user_id" => "u_1", "team" => "growth" },
        )

        expect(result).must_be_instance_of Riffer::Messages::Assistant
      end
    end
  end

  describe "tool calling" do
    let(:weather_tool) do
      stub_tool("GetWeather") do
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    it "declares tool parameters as JSON Schema" do
      provider = Riffer::Providers::Gemini.new
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tools: [weather_tool] })

      expect(result[:tools]).must_equal [{
        functionDeclarations: [{
          name: weather_tool.name,
          description: weather_tool.description,
          parametersJsonSchema: weather_tool.parameters_schema,
        }],
      }]
    end

    describe "#generate_text with tools" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/parses_arguments") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          )
          args = JSON.parse(result.tool_calls.first.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end

      it "includes tool call id" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_generate_text/includes_ids") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.call_id).wont_be_nil
        end
      end
    end

    describe "thought signatures" do
      let(:provider) { Riffer::Providers::Gemini.new }
      let(:model) { "gemini-3.5-flash-lite" }
      let(:format) { Riffer::Providers::Gemini::REASONING_FORMAT }
      let(:question) { Riffer::Messages::User.new("What is the weather in Toronto?") }
      let(:signed_response) do
        toronto = { id: "call_1", name: "get_weather", args: { city: "Toronto" } }
        paris = { id: "call_2", name: "get_weather", args: { city: "Paris" } }
        parts = [
          { text: "Checking.", thoughtSignature: "text-sig" },
          { functionCall: toronto, thoughtSignature: "call-sig" },
          { functionCall: paris },
        ]
        { candidates: [{ content: { parts: parts } }] }
      end

      def tool_result(tool_call)
        Riffer::Messages::Tool.new(
          "15 degrees Celsius and sunny.",
          tool_call_id: tool_call.call_id,
          name: tool_call.name,
        )
      end

      it "keeps each signature as an encrypted part tied to its tool call" do
        tool_calls = provider.send(:extract_tool_calls, signed_response)
        parts = provider.send(:extract_reasoning, signed_response)

        expect(parts.map(&:to_h)).must_equal [
          { type: :encrypted, data: "text-sig", format: format },
          { type: :encrypted, data: "call-sig", id: tool_calls.first.call_id, format: format },
        ]
      end

      it "makes its own call ids rather than using Gemini's" do
        call_ids = provider.send(:extract_tool_calls, signed_response).map(&:call_id)

        expect(call_ids).must_be(:all?) { |id| id.match?(/\Agemini_call_\h{24}\z/) }
      end

      it "puts each signature back on the part it came on and skips other formats" do
        foreign = Riffer::Messages::Assistant::ReasoningPart.new(
          type: :encrypted,
          data: "foreign",
          format: "anthropic-messages-v1",
        )
        message = Riffer::Messages::Assistant.new(
          "Checking.",
          tool_calls: provider.send(:extract_tool_calls, signed_response),
          reasoning: provider.send(:extract_reasoning, signed_response) + [foreign],
        )

        result = provider.send(:convert_assistant_to_gemini_format, message)

        expect(result[:parts]).must_equal [
          { text: "Checking.", thoughtSignature: "text-sig" },
          { functionCall: { name: "get_weather", args: { "city" => "Toronto" } }, thoughtSignature: "call-sig" },
          { functionCall: { name: "get_weather", args: { "city" => "Paris" } } },
        ]
      end

      it "replays the signature across a tool call round trip" do
        VCR.use_cassette("Riffer_Providers_Gemini/thought_signatures/_generate_text/tool_call_round_trip") do
          first = provider.generate_text(messages: [question], model: model, tools: [weather_tool])
          tool_call = first.tool_calls.first

          expect(first.reasoning.find { |part| part.id == tool_call.call_id }&.data).wont_be_nil

          history = [question, first, tool_result(tool_call)]
          second = provider.generate_text(messages: history, model: model, tools: [weather_tool])

          expect(second.content).must_include "15"
        end
      end

      it "replays a streamed signature across a tool call round trip" do
        VCR.use_cassette("Riffer_Providers_Gemini/thought_signatures/_stream_text/tool_call_round_trip") do
          events = provider.stream_text(messages: [question], model: model, tools: [weather_tool]).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          parts = events.grep(Riffer::StreamEvents::ReasoningDone).map(&:part)
          tool_call = Riffer::Messages::Assistant::ToolCall.new(
            call_id: tool_done.call_id,
            name: tool_done.name,
            arguments: tool_done.arguments,
          )

          expect(parts.find { |part| part.id == tool_call.call_id }&.data).wont_be_nil

          history = [
            question,
            Riffer::Messages::Assistant.new("", tool_calls: [tool_call], reasoning: parts),
            tool_result(tool_call),
          ]
          second = provider.stream_text(messages: history, model: model, tools: [weather_tool]).to_a
          text_done = second.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(text_done.content).must_include "15"
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(tool_done).wont_be_nil
        end
      end

      it "includes tool name in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_stream_text/tool_call_done_has_name") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }

          expect(tool_done.name).must_equal "get_weather"
        end
      end

      it "includes arguments in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_Gemini/tool_calling/_stream_text/tool_call_done_has_arguments") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "gemini-3.5-flash-lite",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          args = JSON.parse(tool_done.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end
    end
  end

  describe "reasoning level" do
    let(:provider) { Riffer::Providers::Gemini.new }
    let(:prompt) { "What is 17 times 23? Reply with just the number." }

    it "passes every level through as the thinking level" do
      Riffer::Agent::Config::REASONING_LEVELS.each do |level|
        expect(provider.send(:default_reasoning_options, level)).must_equal(
          { thinkingConfig: { thinkingLevel: level.to_s } },
        )
      end
    end

    it "reasons at a thinking level on a live model" do
      VCR.use_cassette("Riffer_Providers_Gemini/reasoning_level/gemini-3-flash-preview/low") do
        result = provider.generate_text(prompt: prompt, model: "gemini-3-flash-preview", riffer_reasoning_level: :low)

        expect(result.content).must_include "391"
      end
    end

    describe "with a catalog entry" do
      before { Riffer.config.catalog_files = [REASONING_CATALOG_PATH] }
      after { Riffer.config.catalog_files = [] }

      it "reasons with a thinking budget on a live model" do
        VCR.use_cassette("Riffer_Providers_Gemini/reasoning_level/gemini-2_5-flash-lite/low") do
          result = provider.generate_text(prompt: prompt, model: "gemini-2.5-flash-lite", riffer_reasoning_level: :low)

          expect(result.content).must_include "391"
        end
      end
    end
  end

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_Gemini/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::Gemini.new
          result = provider.generate_text(prompt: "Say hello", model: "gemini-3.5-flash-lite")

          expect(result.token_usage).wont_be_nil
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event" do
        VCR.use_cassette("Riffer_Providers_Gemini/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::Gemini.new
          events = provider.stream_text(prompt: "Say hello", model: "gemini-3.5-flash-lite").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done).wont_be_nil
        end
      end
    end

    describe "cache read tokens" do
      it "surfaces cachedContentTokenCount when present" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20, cachedContentTokenCount: 80 } },
        )

        expect(usage.cache_read_tokens).must_equal 80
      end

      it "leaves cache_read_tokens nil when absent" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 } },
        )

        expect(usage.cache_read_tokens).must_be_nil
      end
    end

    describe "thinking tokens" do
      it "folds thoughtsTokenCount into output_tokens" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20, thoughtsTokenCount: 30 } },
        )

        expect(usage.output_tokens).must_equal 50
      end

      it "keeps output_tokens as candidatesTokenCount when absent" do
        provider = Riffer::Providers::Gemini.new
        usage = provider.send(
          :extract_token_usage,
          { usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20 } },
        )

        expect(usage.output_tokens).must_equal 20
      end
    end
  end

  describe "file handling" do
    let(:image_base64) do
      <<~BASE64.chomp
        iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg==
      BASE64
    end

    describe "#generate_text with image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Gemini/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Gemini.new
          file = Riffer::Messages::User::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gemini-3.5-flash-lite", files: [file])

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_Gemini/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Gemini.new
          file = Riffer::Messages::User::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "gemini-3.5-flash-lite", files: [file])

          expect(result.content).wont_be_empty
        end
      end
    end
  end
end
