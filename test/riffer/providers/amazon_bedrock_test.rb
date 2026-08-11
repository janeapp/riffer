# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::AmazonBedrock do
  let(:api_token) { ENV.fetch("AWS_BEDROCK_API_TOKEN", "test_api_token") }

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::AmazonBedrock.semconv_provider_name).must_equal "aws.bedrock"
    end
  end

  describe "finish reasons" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1") }

    it "normalizes end_turn to stop" do
      expect(provider.send(:build_finish_reason, "end_turn").reason).must_equal :stop
    end

    it "normalizes max_tokens to length" do
      expect(provider.send(:build_finish_reason, "max_tokens").reason).must_equal :length
    end

    it "normalizes tool_use to tool_calls" do
      expect(provider.send(:build_finish_reason, "tool_use").reason).must_equal :tool_calls
    end

    it "normalizes guardrail_intervened to content_filter" do
      expect(provider.send(:build_finish_reason, "guardrail_intervened").reason).must_equal :content_filter
    end

    it "normalizes content_filtered to content_filter" do
      expect(provider.send(:build_finish_reason, "content_filtered").reason).must_equal :content_filter
    end

    it "normalizes unknown values to other and keeps the raw value" do
      finish_reason = provider.send(:build_finish_reason, "mystery")

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:other, "mystery"]
    end

    it "returns nil without a stop reason" do
      expect(provider.send(:build_finish_reason, nil)).must_be_nil
    end

    it "extracts the finish reason when generating" do
      VCR.use_cassette(
        "Riffer_Providers_AmazonBedrock/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
      ) do
        result = provider.generate_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

        expect(result.finish_reason).must_equal :stop
      end
    end

    it "emits a FinishReasonDone event when streaming" do
      VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_stream_events") do
        events = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        done = events.find { |e| e.is_a?(Riffer::StreamEvents::FinishReasonDone) }

        expect(done.finish_reason).must_equal :stop
      end
    end
  end

  describe ".skills_adapter" do
    it "returns XmlAdapter for a bare anthropic.* model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("anthropic.claude-3-5-sonnet-20241022-v2:0")

      expect(adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns XmlAdapter for a cross-region us.anthropic.* model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("us.anthropic.claude-sonnet-4-6")

      expect(adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns XmlAdapter for a cross-region eu.anthropic.* model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("eu.anthropic.claude-haiku-4-5-20251001-v1:0")

      expect(adapter).must_equal Riffer::Skills::XmlAdapter
    end

    it "returns MarkdownAdapter for a non-Anthropic model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("us.amazon.nova-lite-v1:0")

      expect(adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "returns MarkdownAdapter for a Meta model id" do
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("meta.llama3-70b-instruct-v1:0")

      expect(adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "returns MarkdownAdapter when model is nil" do
      expect(Riffer::Providers::AmazonBedrock.skills_adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "does not match a stray 'anthropic' substring without a dot boundary" do
      # Guards against regex drift: a model id like "panthropic-..." must not
      # be treated as Anthropic just because it contains the substring.
      adapter = Riffer::Providers::AmazonBedrock.skills_adapter("panthropic-foo")

      expect(adapter).must_equal Riffer::Skills::MarkdownAdapter
    end
  end

  describe "#initialize" do
    it "creates the provider with an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")

      expect(provider).must_be_instance_of Riffer::Providers::AmazonBedrock
    end

    it "sets the region on the default client with an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")

      assert_equal "us-east-1", provider.send(:client).config.region
    end

    it "creates the provider without an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(region: "us-east-1")

      expect(provider).must_be_instance_of Riffer::Providers::AmazonBedrock
    end

    it "sets the region on the default client without an api_token" do
      provider = Riffer::Providers::AmazonBedrock.new(region: "us-east-1")

      assert_equal "us-east-1", provider.send(:client).config.region
    end

    it "raises on unknown constructor options" do
      expect { Riffer::Providers::AmazonBedrock.new(region: "us-east-1", retry_limit: 60) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    after { Riffer.config.amazon_bedrock.client = nil }

    it "uses the configured client" do
      configured = Object.new
      Riffer.config.amazon_bedrock.client = configured

      expect(Riffer::Providers::AmazonBedrock.new.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.amazon_bedrock.client = -> { calls += 1 }
      provider = Riffer::Providers::AmazonBedrock.new

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "passes the agent context to a client Proc with arity" do
      received = nil
      Riffer.config.amazon_bedrock.client = ->(context) { received = context }
      provider = Riffer::Providers::AmazonBedrock.new
      provider.context = Riffer::Agent::Context.new({ tenant: "acme" })

      provider.send(:client)

      expect(received[:tenant]).must_equal "acme"
    end

    it "prefers constructor credentials over the configured client" do
      Riffer.config.amazon_bedrock.client = Object.new
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")

      expect(provider.send(:client)).must_be_instance_of Aws::BedrockRuntime::Client
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/when_prompt_is_provided/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/when_system_and_prompt_are_provided/" \
          "returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          params = { system: "Be concise", prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0" }
          result = provider.generate_text(**params)

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            { role: "system", content: "Be concise" },
            { role: "user", content: "Say hello" },
          ]
          result = provider.generate_text(messages: messages, model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/with_a_System_message/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello"),
          ]
          result = provider.generate_text(messages: messages, model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/with_an_Assistant_message/returns_an_Assistant_message",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?"),
          ]
          result = provider.generate_text(messages: messages, model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

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
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output,
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
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output,
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
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output,
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
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: structured_output,
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
          structured_output = Riffer::Agent::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
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

      it "returns valid JSON with nested object content" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/structured_output_nested_object/returns_nested_json",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: nested_object_prompt,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
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

    describe "structured output with null optional fields" do
      let(:null_optional_prompt) do
        "Extract info from: Jane works at 42 King St in Vancouver. No other details are known. " \
          "Return null for any unknown fields."
      end

      let(:null_optional_structured_output) do
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

      it "returns null for optional fields when info is unavailable" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/structured_output_null_optionals/" \
          "returns_null_for_optional_fields",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: null_optional_prompt,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: null_optional_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["name"]).must_include "Jane"
          expect(parsed["address"]["street"]).must_include "42 King"
          expect(parsed["address"]["city"]).must_include "Vancouver"
          so = null_optional_structured_output.parse_and_validate(result.content)

          expect(so.success?).must_equal true
          expect(so.object[:address][:postal_code]).must_be_nil
          expect(so.object[:address][:country]).must_be_nil
        end
      end
    end

    describe "structured output with optional enum" do
      let(:session_types) { %w[in_person online both] }

      let(:optional_enum_structured_output) do
        params = Riffer::Params.new
        params.required(:name, String, description: "Session name")
        params.optional(:session_type, String, enum: session_types, description: "Type of session")
        Riffer::Agent::StructuredOutput.new(params)
      end

      it "returns an enum value when present" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/structured_output_optional_enum/returns_enum_value",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "Classify the session: yoga class, in-person format. Return session_type from the enum.",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: optional_enum_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["name"]).must_be_instance_of String
          expect(session_types).must_include parsed["session_type"]
        end
      end

      it "returns null when the enum value is unknown" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/structured_output_optional_enum/returns_null",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "Classify the session: yoga class, underwater format. The session_type enum does not " \
                    "cover this, return null for session_type.",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            structured_output: optional_enum_structured_output,
          )
          parsed = JSON.parse(result.content)

          expect(parsed["name"]).must_be_instance_of String
          expect(parsed["session_type"]).must_be_nil
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
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_generate_text/structured_output_typed_array/returns_typed_arrays",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: typed_array_prompt,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
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
          "Riffer_Providers_AmazonBedrock/_generate_text/structured_output_array_of_objects/returns_array_of_objects",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: array_of_objects_prompt,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
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
  end

  describe "tags" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1") }
    let(:messages) { [Riffer::Messages::User.new("Hello")] }
    let(:model) { "us.anthropic.claude-haiku-4-5-20251001-v1:0" }

    # Tags arrive already normalized (Run stringifies keys/values and drops nils
    # before they reach the provider), so these pass clean String=>String maps.
    it "maps all tags (including the reserved user_id) to request_metadata" do
      params = provider.send(
        :build_request_params,
        messages,
        model,
        { tags: { "team" => "growth", "user_id" => "u_1" } },
      )

      expect(params[:request_metadata]).must_equal({ "team" => "growth", "user_id" => "u_1" })
    end

    it "omits request_metadata when no tags are given" do
      params = provider.send(:build_request_params, messages, model, {})

      expect(params.key?(:request_metadata)).must_equal false
    end

    it "does not pass tags through to API params" do
      params = provider.send(:build_request_params, messages, model, { tags: { "team" => "growth" } })

      expect(params.key?(:tags)).must_equal false
    end
  end

  describe "per-call tags (end-to-end)" do
    let(:provider) { Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2") }

    it "forwards per-call tags to the request" do
      VCR.use_cassette("Riffer_Providers_AmazonBedrock/tags/forwards_request_metadata") do
        result = provider.generate_text(
          prompt: "Say hello",
          model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
          tags: { "user_id" => "u_1", "team" => "growth" },
        )

        expect(result).must_be_instance_of Riffer::Messages::Assistant
      end
    end
  end

  describe "#extract_content" do
    let(:provider) do
      # Instantiating triggers depends_on "aws-sdk-bedrockruntime", which makes
      # the Aws::BedrockRuntime::Types constants below available.
      Riffer::Providers::AmazonBedrock.new(api_token: "test", region: "us-east-1")
    end

    def build_response(content_blocks)
      Aws::BedrockRuntime::Types::ConverseResponse.new(
        output: Aws::BedrockRuntime::Types::ConverseOutput::Message.new(
          message: Aws::BedrockRuntime::Types::Message.new(
            role: "assistant",
            content: content_blocks,
          ),
        ),
      )
    end

    it "concatenates multiple text blocks in order" do
      provider # force SDK load before constructing Aws types below
      # Bedrock splits output across several text blocks when reasoning or
      # tool_use blocks are interleaved, so all text blocks must be preserved.
      response = build_response(
        [
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "Hello "),
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "world"),
        ],
      )

      expect(provider.send(:extract_content, response)).must_equal "Hello world"
    end

    it "ignores tool_use blocks when extracting text" do
      provider # force SDK load before constructing Aws types below
      response = build_response(
        [
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "Answer: "),
          Aws::BedrockRuntime::Types::ContentBlock.new(
            tool_use: Aws::BedrockRuntime::Types::ToolUseBlock.new(
              tool_use_id: "id-1",
              name: "calculator",
              input: {},
            ),
          ),
          Aws::BedrockRuntime::Types::ContentBlock.new(text: "42"),
        ],
      )

      expect(provider.send(:extract_content, response)).must_equal "Answer: 42"
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_TextDelta_events",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
          deltas = events.grep(Riffer::StreamEvents::TextDelta)

          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_stream_text/when_messages_are_provided/yields_stream_events",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
          )

          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette(
          "Riffer_Providers_AmazonBedrock/_stream_text/when_messages_are_provided/yields_stream_events",
        ) do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            messages: [{ role: "user", content: "Say hello" }],
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
          ).to_a

          expect(events).wont_be_empty
        end
      end
    end

    describe "when the stream emits an exception event" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new(api_token: "test", region: "us-east-1") }

      def stub_stream_events(provider, events)
        stream_double = Object.new
        stream_double.define_singleton_method(:on_event) { |&block| events.each { |e| block.call(e) } }
        client_double = Object.new
        client_double.define_singleton_method(:converse_stream) { |**_kwargs, &block| block.call(stream_double) }
        provider.instance_variable_set(:@default_client, client_double)
      end

      # Covers the Types → Errors conversion for every stream-exception event
      # type that Bedrock's ConverseStream can emit. Each Types::X struct must
      # map to the same-named Aws::BedrockRuntime::Errors::X service error.
      {
        InternalServerException: :internal_server_exception,
        ModelStreamErrorException: :model_stream_error_exception,
        ThrottlingException: :throttling_exception,
        ValidationException: :validation_exception,
        ServiceUnavailableException: :service_unavailable_exception,
      }.each do |class_name, event_type|
        it "raises Aws::BedrockRuntime::Errors::#{class_name} for a #{event_type} event" do
          provider # force SDK load so the Aws constants resolve below
          type_klass = Aws::BedrockRuntime::Types.const_get(class_name)
          error_klass = Aws::BedrockRuntime::Errors.const_get(class_name)
          event = type_klass.new(message: "boom", event_type: event_type)
          stub_stream_events(provider, [event])

          error = assert_raises(error_klass) do
            provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
          end
          expect(error.message).must_equal "boom"
        end
      end

      it "raises for a model_stream_error_exception mid-stream after content deltas" do
        provider # force SDK load before constructing the Aws types below
        delta_event = Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
          delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: "Hel"),
          content_block_index: 0,
          event_type: :content_block_delta,
        )
        error_event = Aws::BedrockRuntime::Types::ModelStreamErrorException.new(
          message: "model failed",
          original_status_code: 500,
          event_type: :model_stream_error_exception,
        )
        stub_stream_events(provider, [delta_event, error_event])

        enum = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")
        assert_raises(Aws::BedrockRuntime::Errors::ModelStreamErrorException) { enum.to_a }
      end

      it "raises for a future exception type not explicitly known (auto-caught by class-name suffix)" do
        # Simulates the SDK adding a new stream-exception type we haven't coded
        # against. The class-name suffix check should still route it through
        # Aws::BedrockRuntime::Errors (DynamicErrors synthesizes the class)
        # rather than silently dropping it.
        provider
        fake_future_exception_class = Struct.new(:message, :event_type) do
          def self.name
            "Aws::BedrockRuntime::Types::HypotheticalFutureException"
          end
        end
        event = fake_future_exception_class.new("surprise", :hypothetical_future_exception)
        stub_stream_events(provider, [event])

        error = assert_raises(Aws::BedrockRuntime::Errors::ServiceError) do
          provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        end
        expect(error).must_be_kind_of Aws::BedrockRuntime::Errors::HypotheticalFutureException
      end

      it "ignores unknown non-exception events (e.g. message_start) without raising" do
        # Forward-compatible: unknown event types that aren't exceptions should be skipped,
        # not raise. Verified with MessageStartEvent which Bedrock emits but we don't consume.
        provider # force SDK load before constructing the Aws types below
        message_start = Aws::BedrockRuntime::Types::MessageStartEvent.new(
          role: "assistant",
          event_type: :message_start,
        )
        metadata = Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent.new(
          usage: Aws::BedrockRuntime::Types::TokenUsage.new(
            input_tokens: 5,
            output_tokens: 3,
            total_tokens: 8,
          ),
          event_type: :metadata,
        )
        stub_stream_events(provider, [message_start, metadata])

        events = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
        usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

        expect(usage_done).wont_be_nil
        expect(usage_done.token_usage.input_tokens).must_equal 5
      end
    end

    describe "text delta accumulation" do
      let(:provider) { Riffer::Providers::AmazonBedrock.new(api_token: "test", region: "us-east-1") }

      def stub_stream_events(provider, events)
        stream_double = Object.new
        stream_double.define_singleton_method(:on_event) { |&block| events.each { |e| block.call(e) } }
        client_double = Object.new
        client_double.define_singleton_method(:converse_stream) { |**_kwargs, &block| block.call(stream_double) }
        provider.instance_variable_set(:@default_client, client_double)
      end

      # Guards the in-place << accumulation of streamed text: the assembled
      # TextDone content must be byte-identical to the plain concatenation of a
      # few hundred deltas. Catches both the frozen-string seed regression (a
      # frozen "" would raise FrozenError on the first delta) and any
      # mutation-aliasing where a shared reference gets clobbered mid-stream.
      it "assembles hundreds of deltas byte-identically to their concatenation" do
        provider # force SDK load before constructing the Aws types below
        deltas = Array.new(500) { |i| format("delta-%<index>03d-%<pad>s ", index: i, pad: "x" * 12) }
        events = deltas.map do |text|
          Aws::BedrockRuntime::Types::ContentBlockDeltaEvent.new(
            delta: Aws::BedrockRuntime::Types::ContentBlockDelta.new(text: text),
            content_block_index: 0,
            event_type: :content_block_delta,
          )
        end
        events << Aws::BedrockRuntime::Types::ContentBlockStopEvent.new(
          content_block_index: 0,
          event_type: :content_block_stop,
        )
        stub_stream_events(provider, events)

        stream_events = provider.stream_text(prompt: "Hi", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a

        expected = deltas.join
        text_done = stream_events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

        expect(text_done).wont_be_nil
        expect(text_done.content).must_equal expected
        expect(text_done.content.bytesize).must_equal expected.bytesize

        # Each TextDelta must still carry its own unmutated fragment, and joining
        # them must reproduce the buffer exactly.
        streamed = stream_events.grep(Riffer::StreamEvents::TextDelta).map(&:content)

        expect(streamed).must_equal deltas
        expect(streamed.join).must_equal expected
      end
    end
  end

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")

          expect(result.token_usage).wont_be_nil
          expect(result.token_usage.input_tokens).must_equal 9
          expect(result.token_usage.output_tokens).must_equal 16
          expect(result.token_usage.total_tokens).must_equal 25
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event with correct token counts" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done).wont_be_nil
          expect(usage_done.token_usage.input_tokens).must_equal 9
          expect(usage_done.token_usage.output_tokens).must_equal 16
          expect(usage_done.token_usage.total_tokens).must_equal 25
        end
      end

      it "yields TokenUsageDone after TextDone" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(prompt: "Say hello", model: "us.anthropic.claude-haiku-4-5-20251001-v1:0").to_a
          text_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          usage_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }

          expect(usage_done_index).must_be :>, text_done_index
        end
      end
    end

    describe "normalization" do
      it "folds cache buckets into input_tokens" do
        provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
        response = Aws::BedrockRuntime::Types::ConverseResponse.new(
          usage: Aws::BedrockRuntime::Types::TokenUsage.new(
            input_tokens: 9,
            output_tokens: 16,
            cache_write_input_tokens: 3,
            cache_read_input_tokens: 100,
          ),
        )
        token_usage = provider.send(:extract_token_usage, response)

        expect(token_usage.input_tokens).must_equal 112
      end

      it "treats unreported cache buckets as zero" do
        provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
        response = Aws::BedrockRuntime::Types::ConverseResponse.new(
          usage: Aws::BedrockRuntime::Types::TokenUsage.new(input_tokens: 9, output_tokens: 16),
        )
        token_usage = provider.send(:extract_token_usage, response)

        expect(token_usage.input_tokens).must_equal 9
      end
    end
  end

  describe "structured output" do
    it "includes output_config.text_format in request params" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      expect(params[:output_config][:text_format][:type]).must_equal "json_schema"
    end

    it "includes json_schema structure with name" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      expect(params[:output_config][:text_format][:structure][:json_schema][:name]).must_equal "response"
    end

    it "serializes schema as JSON string" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      schema_json = params[:output_config][:text_format][:structure][:json_schema][:schema]

      expect(schema_json).must_be_instance_of String
      parsed = JSON.parse(schema_json)

      expect(parsed["type"]).must_equal "object"
    end

    it "does not include output_config when not configured" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "us.anthropic.claude-haiku-4-5-20251001-v1:0", {})

      expect(params.key?(:output_config)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::Agent::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(
        :build_request_params,
        messages,
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        { structured_output: structured_output },
      )

      expect(params.key?(:structured_output)).must_equal false
    end
  end

  describe "prompt caching" do
    let(:model) { "us.anthropic.claude-haiku-4-5-20251001-v1:0" }
    let(:cache_tool) do
      Class.new(Riffer::Tool) do
        identifier "get_weather"
        description "Get the current weather for a city"
        params do
          required :city, String, description: "The city name"
        end
      end
    end

    it "appends a cachePoint after the system array when a system prompt is present" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })

      expect(params[:system].last).must_equal({ cache_point: { type: "default" } })
    end

    it "appends a cachePoint after the tools when there is no system prompt" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(
        :build_request_params,
        messages,
        model,
        { cache_control: { type: "ephemeral" }, tools: [cache_tool] },
      )

      expect(params[:tool_config][:tools].last).must_equal({ cache_point: { type: "default" } })
    end

    it "translates the ttl onto the cachePoint" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(
        :build_request_params,
        messages,
        model,
        { cache_control: { type: "ephemeral", ttl: "1h" } },
      )

      expect(params[:system].last[:cache_point][:ttl]).must_equal "1h"
    end

    it "does not pass cache_control through as a top-level param" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, model, { cache_control: { type: "ephemeral" } })

      expect(params.key?(:cache_control)).must_equal false
    end

    it "adds no cachePoint when caching is not requested" do
      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      messages = [Riffer::Messages::System.new("Be concise"), Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, model, {})

      expect(params[:system].none? { |block| block.key?(:cache_point) }).must_equal true
    end
  end

  describe "file handling" do
    let(:image_base64) do
      "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/" \
        "oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg=="
    end

    describe "#generate_text with image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(
            prompt: "Describe this image",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(
            prompt: "Describe this image",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          )

          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#generate_text with document" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          pdf_data = Base64.strict_encode64(
            "%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n" \
            "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n" \
            "3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\n" \
            "xref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n" \
            "trailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF",
          )
          file = Riffer::Messages::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test")
          result = provider.generate_text(
            prompt: "What is in this document?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          pdf_data = Base64.strict_encode64(
            "%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n" \
            "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n" \
            "3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\n" \
            "xref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n" \
            "trailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF",
          )
          file = Riffer::Messages::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test")
          result = provider.generate_text(
            prompt: "What is in this document?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          )

          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with document" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          pdf_data = Base64.strict_encode64(
            "%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n" \
            "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n" \
            "3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\n" \
            "xref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n" \
            "trailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF",
          )
          file = Riffer::Messages::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test")
          events = provider.stream_text(
            prompt: "What is in this document?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          ).to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          pdf_data = Base64.strict_encode64(
            "%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n" \
            "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n" \
            "3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\n" \
            "xref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n" \
            "trailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF",
          )
          file = Riffer::Messages::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test")
          events = provider.stream_text(
            prompt: "What is in this document?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          ).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "#stream_text with image" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          events = provider.stream_text(
            prompt: "Describe this image",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          ).to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          file = Riffer::Messages::FilePart.new(data: image_base64, media_type: "image/png")
          events = provider.stream_text(
            prompt: "Describe this image",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          ).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    let(:image_s3_uri) { ENV.fetch("AWS_TEST_IMAGE_S3_URI", "s3://riffer-test-bucket/super-secret-image.png") }
    let(:document_s3_uri) { ENV.fetch("AWS_TEST_DOCUMENT_S3_URI", "s3://riffer-test-bucket/super-secret-document.pdf") }

    describe "#generate_text with S3 URI image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_s3_uri_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.from_url(image_s3_uri)
          result = provider.generate_text(
            prompt: "Describe this image",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_s3_uri_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.from_url(image_s3_uri)
          result = provider.generate_text(
            prompt: "Describe this image",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          )

          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#generate_text with S3 URI document" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_s3_uri_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.new(
            media_type: "application/pdf",
            filename: "super-secret-document",
            url: document_s3_uri,
          )
          result = provider.generate_text(
            prompt: "What is in this document?",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_generate_text/with_s3_uri_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.new(
            media_type: "application/pdf",
            filename: "super-secret-document",
            url: document_s3_uri,
          )
          result = provider.generate_text(
            prompt: "What is in this document?",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          )

          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with S3 URI image" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_s3_uri_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.from_url(image_s3_uri)
          events = provider.stream_text(
            prompt: "Describe this image",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          ).to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_s3_uri_image") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.from_url(image_s3_uri)
          events = provider.stream_text(
            prompt: "Describe this image",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          ).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "#stream_text with S3 URI document" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_s3_uri_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.new(
            media_type: "application/pdf",
            filename: "super-secret-document",
            url: document_s3_uri,
          )
          events = provider.stream_text(
            prompt: "What is in this document?",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          ).to_a

          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/file_handling/_stream_text/with_s3_uri_document") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-west-2")
          file = Riffer::Messages::FilePart.new(
            media_type: "application/pdf",
            filename: "super-secret-document",
            url: document_s3_uri,
          )
          events = provider.stream_text(
            prompt: "What is in this document?",
            model: "us.amazon.nova-lite-v1:0",
            files: [file],
          ).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }

          expect(done).wont_be_nil
        end
      end
    end

    describe "with unsupported URL source" do
      it "raises ArgumentError for non-S3 URLs" do
        provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
        file = Riffer::Messages::FilePart.from_url("https://example.com/image.png")

        expect do
          provider.generate_text(
            prompt: "Describe this",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            files: [file],
          )
        end.
          must_raise Riffer::ArgumentError
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

      provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
      format = provider.send(:convert_tool_to_bedrock_format, tool)
      schema = format[:tool_spec][:input_schema][:json]

      expect(schema[:required]).must_include "age"
      expect(schema[:properties]["age"][:type]).must_equal %w[integer null]
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
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          )

          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/parses_arguments") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
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
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          )

          expect(result.tool_calls.first.call_id).wont_be_nil
        end
      end
    end

    describe "#generate_text with Tool message in history" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new(
              "",
              tool_calls: [
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "tooluse_123",
                  name: "get_weather",
                  arguments: '{"city":"Toronto"}',
                ),
              ],
            ),
            Riffer::Messages::Tool.new(
              "The weather in Toronto is 15 degrees Celsius.",
              tool_call_id: "tooluse_123",
              name: "get_weather",
            ),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new(
              "",
              tool_calls: [
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "tooluse_123",
                  name: "get_weather",
                  arguments: '{"city":"Toronto"}',
                ),
              ],
            ),
            Riffer::Messages::Tool.new(
              "The weather in Toronto is 15 degrees Celsius.",
              tool_call_id: "tooluse_123",
              name: "get_weather",
            ),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
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
            Riffer::Messages::Assistant.new(
              "",
              tool_calls: [
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M",
                  name: "get_weather",
                  arguments: '{"city":"Toronto"}',
                ),
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ",
                  name: "get_weather",
                  arguments: '{"city":"Vancouver"}',
                ),
              ],
            ),
            Riffer::Messages::Tool.new(
              "Toronto: 15°C",
              tool_call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M",
              name: "get_weather",
            ),
            Riffer::Messages::Tool.new(
              "Vancouver: 12°C",
              tool_call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ",
              name: "get_weather",
            ),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          )

          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_generate_text/with_multiple_tool_messages") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto and Vancouver?"),
            Riffer::Messages::Assistant.new(
              "",
              tool_calls: [
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M",
                  name: "get_weather",
                  arguments: '{"city":"Toronto"}',
                ),
                Riffer::Messages::Assistant::ToolCall.new(
                  call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ",
                  name: "get_weather",
                  arguments: '{"city":"Vancouver"}',
                ),
              ],
            ),
            Riffer::Messages::Tool.new(
              "Toronto: 15°C",
              tool_call_id: "tooluse_bdrk_01JK5WNRW22T9YKB4V02NE2S9M",
              name: "get_weather",
            ),
            Riffer::Messages::Tool.new(
              "Vancouver: 12°C",
              tool_call_id: "tooluse_bdrk_01JK5WNRWNN4CR0E4R2ZYDNJYZ",
              name: "get_weather",
            ),
          ]
          result = provider.generate_text(
            messages: messages,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
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
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          ).to_a
          tool_deltas = events.grep(Riffer::StreamEvents::ToolCallDelta)

          expect(tool_deltas).wont_be_empty
        end
      end

      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_AmazonBedrock/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::AmazonBedrock.new(api_token: api_token, region: "us-east-1")
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
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
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
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
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            tools: [weather_tool],
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          args = JSON.parse(tool_done.arguments)

          expect(args["city"]).must_equal "Toronto"
        end
      end
    end
  end
end
