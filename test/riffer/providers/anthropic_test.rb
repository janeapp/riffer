# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Anthropic do
  let(:api_key) { ENV.fetch("ANTHROPIC_API_KEY", "test_api_key") }

  describe "#initialize" do
    it "creates Anthropic client with an api_key" do
      provider = Riffer::Providers::Anthropic.new(api_key: api_key)
      expect(provider).must_be_instance_of Riffer::Providers::Anthropic
    end

    it "accepts additional options" do
      provider = Riffer::Providers::Anthropic.new(api_key: api_key, timeout: 60)
      expect(provider).must_be_instance_of Riffer::Providers::Anthropic
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          params = {system: "Be concise", prompt: "Say hello", model: "claude-haiku-4-5-20251001"}
          result = provider.generate_text(**params)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          messages = [
            {role: "system", content: "Be concise"},
            {role: "user", content: "Say hello"}
          ]
          result = provider.generate_text(messages: messages, model: "claude-haiku-4-5-20251001")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "claude-haiku-4-5-20251001")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello")
          ]
          result = provider.generate_text(messages: messages, model: "claude-haiku-4-5-20251001")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/with_an_Assistant_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?")
          ]
          result = provider.generate_text(messages: messages, model: "claude-haiku-4-5-20251001")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end
    describe "structured output" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "claude-haiku-4-5-20251001",
            structured_output: structured_output
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns non-empty content" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "claude-haiku-4-5-20251001",
            structured_output: structured_output
          )
          expect(result.content).wont_be_empty
        end
      end

      it "returns valid JSON content" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "claude-haiku-4-5-20251001",
            structured_output: structured_output
          )
          JSON.parse(result.content)
        end
      end

      it "includes sentiment key" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "claude-haiku-4-5-20251001",
            structured_output: structured_output
          )
          parsed = JSON.parse(result.content)
          expect(parsed.key?("sentiment")).must_equal true
        end
      end

      it "includes score key" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_generate_text/structured_output/returns_structured_json") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          params = Riffer::Params.new
          params.required(:sentiment, String)
          params.required(:score, Float)
          structured_output = Riffer::StructuredOutput.new(params)
          result = provider.generate_text(
            prompt: "Analyze the sentiment of the following text: 'I love this product, it is amazing!'",
            model: "claude-haiku-4-5-20251001",
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
        VCR.use_cassette("Riffer_Providers_Anthropic/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.stream_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001")
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001").to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001").to_a
          deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "claude-haiku-4-5-20251001"
          )
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "claude-haiku-4-5-20251001"
          ).to_a
          expect(events).wont_be_empty
        end
      end
    end
  end

  describe "structured output" do
    it "includes output_config.format in request params" do
      provider = Riffer::Providers::Anthropic.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      params.required(:score, Float)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "claude-haiku-4-5-20251001", {structured_output: structured_output})

      expect(params[:output_config][:format][:type]).must_equal "json_schema"
    end

    it "includes json_schema in format" do
      provider = Riffer::Providers::Anthropic.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "claude-haiku-4-5-20251001", {structured_output: structured_output})

      expect(params[:output_config][:format][:schema][:type]).must_equal "object"
    end

    it "does not include output_config when not configured" do
      provider = Riffer::Providers::Anthropic.new(api_key: api_key)
      messages = [Riffer::Messages::User.new("Hello")]

      params = provider.send(:build_request_params, messages, "claude-haiku-4-5-20251001", {})

      expect(params.key?(:output_config)).must_equal false
    end

    it "does not pass structured_output through to API params" do
      provider = Riffer::Providers::Anthropic.new(api_key: api_key)
      params = Riffer::Params.new
      params.required(:sentiment, String)
      structured_output = Riffer::StructuredOutput.new(params)
      messages = [Riffer::Messages::User.new("Analyze")]

      params = provider.send(:build_request_params, messages, "claude-haiku-4-5-20251001", {structured_output: structured_output})

      expect(params.key?(:structured_output)).must_equal false
    end
  end

  describe "web search" do
    describe "#generate_text with web_search" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_generate_text/returns_an_Assistant_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: true)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "accepts hash web_search options" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_generate_text/accepts_hash_web_search_options") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: {max_uses: 3})
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "#stream_text with web_search" do
      it "yields WebSearchStatus events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_stream_text/yields_web_search_status") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: true).to_a
          web_search_statuses = events.select { |e| e.is_a?(Riffer::StreamEvents::WebSearchStatus) }
          expect(web_search_statuses).wont_be_empty
        end
      end

      it "yields WebSearchDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_stream_text/yields_web_search_result") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: true).to_a
          web_search_result = events.find { |e| e.is_a?(Riffer::StreamEvents::WebSearchDone) }
          expect(web_search_result).wont_be_nil
        end
      end

      it "includes sources in WebSearchDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_stream_text/yields_web_search_result") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: true).to_a
          web_search_result = events.find { |e| e.is_a?(Riffer::StreamEvents::WebSearchDone) }
          expect(web_search_result.sources).wont_be_empty
          expect(web_search_result.sources.first[:title]).wont_be_nil
          expect(web_search_result.sources.first[:url]).wont_be_nil
        end
      end

      it "includes query in WebSearchStatus searching event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_stream_text/yields_web_search_status") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: true).to_a
          searching_status = events.find { |e| e.is_a?(Riffer::StreamEvents::WebSearchStatus) && e.status == "searching" }
          expect(searching_status).wont_be_nil
          expect(searching_status.query).wont_be_empty
        end
      end

      it "does not yield ToolCallDelta events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/web_search/_stream_text/no_phantom_tool_call_delta") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "What is the latest Ruby version?", model: "claude-haiku-4-5-20251001", web_search: true).to_a
          tool_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDelta) }
          expect(tool_deltas).must_be_empty
        end
      end
    end
  end

  describe "file handling" do
    let(:image_base64) { "iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAIAAACRXR/mAAAAQ0lEQVR4nO3OMQ0AMAwDsPAnvRHonxyWDMB5yaD+QEtLS0tLa0N/oKWlpaWltaE/0NLS0tLS2tAfaGlpaWlpbegPTh97K7rEaOcNTQAAAABJRU5ErkJggg==" }

    describe "#generate_text with image" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "claude-haiku-4-5-20251001", files: [file])
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_generate_text/with_image") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          result = provider.generate_text(prompt: "Describe this image", model: "claude-haiku-4-5-20251001", files: [file])
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#generate_text with document" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_generate_text/with_document") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          result = provider.generate_text(prompt: "What is in this document?", model: "claude-haiku-4-5-20251001", files: [file])
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns content" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_generate_text/with_document") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          result = provider.generate_text(prompt: "What is in this document?", model: "claude-haiku-4-5-20251001", files: [file])
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with document" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_stream_text/with_document") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          events = provider.stream_text(prompt: "What is in this document?", model: "claude-haiku-4-5-20251001", files: [file]).to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_stream_text/with_document") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          pdf_data = Base64.strict_encode64("%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Resources<<>>>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n206\n%%EOF")
          file = Riffer::FilePart.new(data: pdf_data, media_type: "application/pdf", filename: "test.pdf")
          events = provider.stream_text(prompt: "What is in this document?", model: "claude-haiku-4-5-20251001", files: [file]).to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end

    describe "#stream_text with image" do
      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_stream_text/with_image") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          events = provider.stream_text(prompt: "Describe this image", model: "claude-haiku-4-5-20251001", files: [file]).to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/file_handling/_stream_text/with_image") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          file = Riffer::FilePart.new(data: image_base64, media_type: "image/png")
          events = provider.stream_text(prompt: "Describe this image", model: "claude-haiku-4-5-20251001", files: [file]).to_a
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
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns tool_calls" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          expect(result.tool_calls).wont_be_empty
        end
      end

      it "returns correct tool name" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/returns_tool_calls") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first.name).must_equal "get_weather"
        end
      end

      it "parses tool call arguments correctly" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/parses_arguments") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          args = JSON.parse(result.tool_calls.first.arguments)
          expect(args["city"]).must_equal "Toronto"
        end
      end

      it "includes tool call id" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/includes_ids") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          expect(result.tool_calls.first.id).wont_be_nil
        end
      end
    end

    describe "#generate_text with Tool message in history" do
      it "returns Assistant message" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              Riffer::Messages::Assistant::ToolCall.new(id: "toolu_123", call_id: "toolu_123", name: "get_weather", arguments: '{"city":"Toronto"}')
            ]),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "toolu_123", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns response with content" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_generate_text/with_tool_message") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("What is the weather in Toronto?"),
            Riffer::Messages::Assistant.new("", tool_calls: [
              Riffer::Messages::Assistant::ToolCall.new(id: "toolu_123", call_id: "toolu_123", name: "get_weather", arguments: '{"city":"Toronto"}')
            ]),
            Riffer::Messages::Tool.new("The weather in Toronto is 15 degrees Celsius.", tool_call_id: "toolu_123", name: "get_weather")
          ]
          result = provider.generate_text(
            messages: messages,
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          )
          expect(result.content).wont_be_empty
        end
      end
    end

    describe "#stream_text with tools" do
      it "yields ToolCallDelta events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_stream_text/yields_tool_call_delta") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          ).to_a
          tool_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ToolCallDelta) }
          expect(tool_deltas).wont_be_empty
        end
      end

      it "yields ToolCallDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_stream_text/yields_tool_call_done") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done).wont_be_nil
        end
      end

      it "includes tool name in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_stream_text/tool_call_done_has_name") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          expect(tool_done.name).must_equal "get_weather"
        end
      end

      it "includes arguments in ToolCallDone" do
        VCR.use_cassette("Riffer_Providers_Anthropic/tool_calling/_stream_text/tool_call_done_has_arguments") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is the weather in Toronto?",
            model: "claude-haiku-4-5-20251001",
            tools: [weather_tool]
          ).to_a
          tool_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ToolCallDone) }
          args = JSON.parse(tool_done.arguments)
          expect(args["city"]).must_equal "Toronto"
        end
      end
    end
  end

  describe "usage" do
    describe "#generate_text returns usage" do
      it "includes usage in the response" do
        VCR.use_cassette("Riffer_Providers_Anthropic/usage/_generate_text/includes_usage") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001")
          expect(result.token_usage).wont_be_nil
          expect(result.token_usage.input_tokens).must_equal 9
          expect(result.token_usage.output_tokens).must_equal 16
          expect(result.token_usage.total_tokens).must_equal 25
        end
      end
    end

    describe "#stream_text yields TokenUsageDone" do
      it "yields TokenUsageDone event with correct token counts" do
        VCR.use_cassette("Riffer_Providers_Anthropic/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001").to_a
          usage_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done).wont_be_nil
          expect(usage_done.token_usage.input_tokens).must_equal 9
          expect(usage_done.token_usage.output_tokens).must_equal 16
          expect(usage_done.token_usage.total_tokens).must_equal 25
        end
      end

      it "yields TokenUsageDone after TextDone" do
        VCR.use_cassette("Riffer_Providers_Anthropic/usage/_stream_text/yields_usage_done") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "claude-haiku-4-5-20251001").to_a
          text_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          usage_done_index = events.index { |e| e.is_a?(Riffer::StreamEvents::TokenUsageDone) }
          expect(usage_done_index).must_be :>, text_done_index
        end
      end
    end
  end

  describe "extended thinking" do
    describe "#generate_text with thinking" do
      it "returns an Assistant message with thinking enabled" do
        VCR.use_cassette("Riffer_Providers_Anthropic/reasoning/_generate_text/with_thinking_enabled") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is 2+2? Think step by step.",
            model: "claude-haiku-4-5-20251001",
            thinking: {type: "enabled", budget_tokens: 10000},
            max_tokens: 16000
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end

      it "returns an Assistant message with custom budget_tokens" do
        VCR.use_cassette("Riffer_Providers_Anthropic/reasoning/_generate_text/with_thinking_budget") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          result = provider.generate_text(
            prompt: "What is 2+2? Think step by step.",
            model: "claude-haiku-4-5-20251001",
            thinking: {type: "enabled", budget_tokens: 5000},
            max_tokens: 16000
          )
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "#stream_text with thinking" do
      it "yields ReasoningDelta events" do
        VCR.use_cassette("Riffer_Providers_Anthropic/reasoning/_stream_text/yields_reasoning_delta") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is 2+2? Think step by step.",
            model: "claude-haiku-4-5-20251001",
            thinking: {type: "enabled", budget_tokens: 10000},
            max_tokens: 16000
          ).to_a
          reasoning_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::ReasoningDelta) }
          expect(reasoning_deltas).wont_be_empty
        end
      end

      it "yields ReasoningDone event" do
        VCR.use_cassette("Riffer_Providers_Anthropic/reasoning/_stream_text/yields_reasoning_done") do
          provider = Riffer::Providers::Anthropic.new(api_key: api_key)
          events = provider.stream_text(
            prompt: "What is 2+2? Think step by step.",
            model: "claude-haiku-4-5-20251001",
            thinking: {type: "enabled", budget_tokens: 10000},
            max_tokens: 16000
          ).to_a
          reasoning_done = events.find { |e| e.is_a?(Riffer::StreamEvents::ReasoningDone) }
          expect(reasoning_done).wont_be_nil
        end
      end
    end
  end
end
