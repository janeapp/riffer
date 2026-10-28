# frozen_string_literal: true

require "test_helper"
require "googleauth"

describe Riffer::Providers::GoogleCloud do
  let(:project_id) { ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project") }
  let(:access_token) { ENV.fetch("GOOGLE_CLOUD_ACCESS_TOKEN", "test_access_token") }
  let(:provider) { Riffer::Providers::GoogleCloud.new }

  before do
    Riffer.config.google_cloud.project_id = project_id
    Riffer.config.google_cloud.credentials = Google::Auth::BearerTokenCredentials.new(token: access_token)
  end

  after do
    Riffer.config.google_cloud.project_id = nil
    Riffer.config.google_cloud.location = nil
    Riffer.config.google_cloud.credentials = nil
    Riffer.config.google_cloud.client = nil
  end

  describe ".semconv_provider_name" do
    it "returns the semconv well-known value" do
      expect(Riffer::Providers::GoogleCloud.semconv_provider_name).must_equal "gcp.vertex_ai"
    end
  end

  describe "#initialize" do
    it "takes no arguments" do
      expect { Riffer::Providers::GoogleCloud.new(project_id: project_id) }.must_raise ArgumentError
    end
  end

  describe "client resolution" do
    it "builds a GoogleCloud::Client from the configured project and location" do
      Riffer.config.google_cloud.location = "europe-west4"
      client = provider.send(:client)

      expect(client).must_be_instance_of Riffer::Providers::GoogleCloud::Client
      expect(client.instance_variable_get(:@location)).must_equal "europe-west4"
      expect(client.instance_variable_get(:@base_url)).must_equal "https://europe-west4-aiplatform.googleapis.com"
    end

    it "passes the configured credentials to the client" do
      credentials = Riffer.config.google_cloud.credentials

      expect(provider.send(:client).instance_variable_get(:@credentials)).must_be_same_as credentials
    end

    it "raises when no project id is configured" do
      Riffer.config.google_cloud.project_id = nil

      expect { provider.send(:client) }.must_raise Riffer::ArgumentError
    end

    it "uses the configured client" do
      configured = Object.new
      Riffer.config.google_cloud.client = configured

      expect(provider.send(:client)).must_be_same_as configured
    end

    it "resolves a configured client Proc on every call" do
      calls = 0
      Riffer.config.google_cloud.client = -> { calls += 1 }

      provider.send(:client)
      provider.send(:client)

      expect(calls).must_equal 2
    end

    it "memoizes the client it builds" do
      expect(provider.send(:client)).must_be_same_as provider.send(:client)
    end

    it "uses a subclass's build_client to bind a location" do
      eu_provider = Class.new(Riffer::Providers::GoogleCloud) do
        private

        def build_client
          Riffer::Providers::GoogleCloud::Client.new(
            project_id: Riffer.config.google_cloud.project_id, location: "eu",
            credentials: Riffer.config.google_cloud.credentials,
          )
        end
      end

      client = eu_provider.new.send(:client)

      expect(client.instance_variable_get(:@base_url)).must_equal "https://aiplatform.eu.rep.googleapis.com"
    end
  end

  describe "model validation" do
    it "raises ArgumentError for model with slashes" do
      expect { provider.generate_text(prompt: "Hello", model: "../admin") }.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError for model with spaces" do
      expect { provider.generate_text(prompt: "Hello", model: "gemini 3.5") }.must_raise Riffer::ArgumentError
    end

    it "addresses Gemini models under the google publisher" do
      expect(provider.send(:api_path, "gemini-3.5-flash-lite", "generateContent")).
        must_equal "publishers/google/models/gemini-3.5-flash-lite:generateContent"
    end

    it "accepts a versioned model id" do
      expect(provider.send(:api_path, "gemini-3.5-flash-lite@001", "generateContent")).
        must_equal "publishers/google/models/gemini-3.5-flash-lite@001:generateContent"
    end
  end

  describe "tags" do
    let(:messages) { [Riffer::Messages::User.new("Hello")] }

    def labels_for(options)
      provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", options)[:labels]
    end

    it "maps tags to labels" do
      expect(labels_for(tags: { "team" => "growth", "user_id" => "u_1" })).
        must_equal({ "team" => "growth", "user_id" => "u_1" })
    end

    it "omits labels without tags" do
      params = provider.send(:build_request_params, messages, "gemini-3.5-flash-lite", { tags: {} })

      expect(params.keys).must_equal %i[model contents]
    end

    it "rewrites keys and values into valid labels" do
      labels = labels_for(tags: { "Team" => "Growth Hacking", "agent" => "support/triage_agent", "région" => "Zürich" })

      expect(labels).must_equal({ "team" => "growth_hacking", "agent" => "support_triage_agent", "région" => "zürich" })
    end

    it "cuts keys and values to 63 characters" do
      labels = labels_for(tags: { "k" * 70 => "v" * 70 })

      expect(labels).must_equal({ "k" * 63 => "v" * 63 })
    end

    it "drops tags whose key doesn't start with a letter or whose value is nil" do
      expect(labels_for(tags: { "1st" => "a", "_x" => "b", "team" => nil, "ok" => "c" })).must_equal({ "ok" => "c" })
    end

    it "merges tags over labels set in model options, a tag winning on a shared key" do
      params = provider.send(
        :build_request_params,
        messages,
        "gemini-3.5-flash-lite",
        { labels: { cost_center: "cc1", team: "ops" }, temperature: 0.5, tags: { "team" => "growth" } },
      )

      expect(params[:labels]).must_equal({ "cost_center" => "cc1", "team" => "growth" })
      expect(params[:generationConfig]).must_equal({ temperature: 0.5 })
    end
  end

  describe "structured output" do
    it "sends the JSON schema as a responseFormat list" do
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

      expect(result[:generationConfig]).must_equal(
        responseFormat: [{
          text: { mimeType: "APPLICATION_JSON", schema: structured_output.json_schema(strict: true) },
        }],
      )
    end
  end

  describe "thought signatures" do
    let(:response) do
      call = { name: "get_weather", args: { city: "Toronto" } }
      { candidates: [{ content: { parts: [{ functionCall: call, thoughtSignature: "agent-platform-sig" }] } }] }
    end

    it "tags signatures with the Google Cloud format" do
      parts = provider.send(:extract_reasoning, response)

      expect(parts.map(&:format)).must_equal ["google-cloud-generate-content-v1"]
    end

    it "swaps Gemini Developer API signatures for the placeholder, since Agent Platform rejects them" do
      tool_call = provider.send(:extract_tool_calls, response).first
      developer_api = Riffer::Messages::Assistant::ReasoningPart.new(
        type: :encrypted,
        data: "developer-api-sig",
        id: tool_call.call_id,
        format: Riffer::Providers::Gemini::REASONING_FORMAT,
      )
      message = Riffer::Messages::Assistant.new("", tool_calls: [tool_call], reasoning: [developer_api])

      result = provider.send(:convert_assistant_to_gemini_format, message)

      expect(result[:parts]).must_equal [{
        functionCall: { name: "get_weather", args: { "city" => "Toronto" } },
        thoughtSignature: Riffer::Providers::Gemini::PLACEHOLDER_SIGNATURE,
      }]
    end
  end

  describe "reasoning level" do
    it "sends the Gemini thinking level in the Agent Platform request" do
      client = Object.new
      client.define_singleton_method(:post) do |path, body|
        @request = [path, body]
        { candidates: [{ content: { parts: [{ text: "391" }] }, finishReason: "STOP" }] }
      end
      Riffer.config.google_cloud.client = client

      provider.generate_text(prompt: "17 * 23?", model: "gemini-3.5-flash-lite", riffer_reasoning_level: :low)
      path, body = client.instance_variable_get(:@request)

      expect(path).must_equal "publishers/google/models/gemini-3.5-flash-lite:generateContent"
      expect(body[:generationConfig]).must_equal({ thinkingConfig: { thinkingLevel: "low" } })
    end
  end
end
