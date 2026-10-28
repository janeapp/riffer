# frozen_string_literal: true

require "test_helper"
require "aws-sdk-bedrockruntime"
require "googleauth"

# Acceptance cassettes only replay. To record against the live APIs, set
# RIFFER_RECORD to a VCR record mode: "once" records missing cassettes, "all"
# re-records every cassette the run touches.
ACCEPTANCE_RECORD_MODE = ENV.fetch("RIFFER_RECORD", "none").to_sym

ACCEPTANCE_FIXTURES_PATH = File.expand_path("fixtures", __dir__)

ACCEPTANCE_CATALOG_PATH = File.join(ACCEPTANCE_FIXTURES_PATH, "catalog.json")

ACCEPTANCE_MODES = %i[generate stream].freeze

ACCEPTANCE_TEMPERATURES = { "Toronto" => 15, "Paris" => 22 }.freeze

ACCEPTANCE_TAGS = { "team" => "growth", "agent" => "support/triage_agent", "user_id" => "u_1" }.freeze

# Providers on Riffer::HTTP::Client raise Riffer::APIError.
HTTP_ERROR_CONTRACT = { class: Riffer::APIError, status: :status.to_proc, detail: :body.to_proc }.freeze

# Every acceptance file runs against each provider here unless it excludes it,
# so a new provider joins every feature by default. An entry holds what the
# tests can't derive: riffer passes model options and web_search options
# through as-is, so their names are the provider's own. token_limit_options
# caps output at 20 tokens, invalid_options is rejected with a 400,
# thinking_options makes the model reason on a simple tool call, and
# cache_options lets a repeated prompt hit the cache. wire_tags is what
# ACCEPTANCE_TAGS adds to the request body, and error_contract the error class
# a failed request raises and how to read its HTTP status and text.
ACCEPTANCE_PROVIDERS = {
  gemini: {
    model: "gemini-3.5-flash-lite",
    reasoning_levels: %i[low medium high],
    token_limit_options: { maxOutputTokens: 20 },
    invalid_options: { temperature: 5 },
    # Gemini thinks by default.
    thinking_options: {},
    # Implicit caching needs no request field.
    cache_options: {},
    web_search_options: { timeRangeFilter: { startTime: "2026-01-01T00:00:00Z", endTime: "2026-10-22T00:00:00Z" } },
    # The Developer API has no request field for tags, so none are sent.
    wire_tags: {},
    error_contract: HTTP_ERROR_CONTRACT,
    configure: -> { Riffer.config.gemini.api_key = ENV.fetch("GEMINI_API_KEY", "test_api_key") },
    break_credentials: -> { Riffer.config.gemini.api_key = "invalid-api-key" },
    reset: -> { Riffer.config.gemini.api_key = nil },
  },
  google_cloud: {
    model: "gemini-3.5-flash-lite",
    reasoning_levels: %i[low medium high],
    token_limit_options: { maxOutputTokens: 20 },
    invalid_options: { temperature: 5 },
    # Gemini thinks by default.
    thinking_options: {},
    # Implicit caching needs no request field.
    cache_options: {},
    web_search_options: { timeRangeFilter: { startTime: "2026-01-01T00:00:00Z", endTime: "2026-10-22T00:00:00Z" } },
    wire_tags: { "labels" => { "team" => "growth", "agent" => "support_triage_agent", "user_id" => "u_1" } },
    error_contract: HTTP_ERROR_CONTRACT,
    configure: lambda do
      Riffer.config.google_cloud.project_id = ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project")
      Riffer.config.google_cloud.credentials = Google::Auth::BearerTokenCredentials.new(
        token: ENV.fetch("GOOGLE_CLOUD_ACCESS_TOKEN", "test_access_token"),
      )
    end,
    break_credentials: lambda do
      Riffer.config.google_cloud.credentials = Google::Auth::BearerTokenCredentials.new(token: "invalid-access-token")
    end,
    reset: lambda do
      Riffer.config.google_cloud.project_id = nil
      Riffer.config.google_cloud.credentials = nil
    end,
  },
  amazon_bedrock: {
    model: "us.anthropic.claude-haiku-5-5",
    reasoning_levels: %i[low medium high max],
    token_limit_options: { inference_config: { max_tokens: 20 } },
    invalid_options: { inference_config: { temperature: 5 } },
    # Below max effort, Haiku 5.5 rarely thinks before a simple tool call.
    thinking_options: {
      additional_model_request_fields: { thinking: { type: "adaptive" }, output_config: { effort: "max" } },
    },
    cache_options: { cache_control: true },
    wire_tags: { "requestMetadata" => ACCEPTANCE_TAGS },
    error_contract: {
      class: Aws::BedrockRuntime::Errors::ServiceError,
      status: ->(error) { error.context.http_response.status_code },
      detail: :message.to_proc,
    },
    # Replay authenticates with a placeholder bearer token. Recording signs
    # with the AWS credentials in the environment when AWS_ACCESS_KEY_ID is set.
    configure: lambda do
      Riffer.config.amazon_bedrock.region = "us-east-1"
      unless ENV["AWS_ACCESS_KEY_ID"]
        Riffer.config.amazon_bedrock.api_token = ENV.fetch("AWS_BEDROCK_API_TOKEN", "test_api_token")
      end
    end,
    break_credentials: -> { Riffer.config.amazon_bedrock.api_token = "invalid-api-token" },
    reset: lambda do
      Riffer.config.amazon_bedrock.region = nil
      Riffer.config.amazon_bedrock.api_token = nil
    end,
  },
}.freeze

def acceptance_cassette(name, &)
  VCR.use_cassette("acceptance/#{name}", record: ACCEPTANCE_RECORD_MODE, &)
end

# +except+ maps each excluded provider to the reason it can't run the feature.
def acceptance_providers(except: {})
  unknown = except.keys - ACCEPTANCE_PROVIDERS.keys
  raise ArgumentError, "Unknown acceptance providers: #{unknown.inspect}" unless unknown.empty?

  ACCEPTANCE_PROVIDERS.keys - except.keys
end

def acceptance_setting(provider_name, key)
  ACCEPTANCE_PROVIDERS.fetch(provider_name).fetch(key)
end

def configure_acceptance_provider(provider_name)
  acceptance_setting(provider_name, :configure).call
end

def break_acceptance_credentials(provider_name)
  acceptance_setting(provider_name, :break_credentials).call
end

def reset_acceptance_provider(provider_name)
  acceptance_setting(provider_name, :reset).call
end

def acceptance_model_id(provider_name)
  "#{provider_name}/#{acceptance_setting(provider_name, :model)}"
end

def acceptance_weather_tool
  stub_tool("GetWeather") do
    description "Get the current weather for a city"
    params { required :city, String, description: "The city name" }

    define_method(:call) do |context:, city:|
      celsius = ACCEPTANCE_TEMPERATURES.fetch(city, 10)
      text("It is #{celsius} degrees Celsius in #{city}.")
    end
  end
end

def weather_result(tool_call)
  city = JSON.parse(tool_call.arguments).fetch("city")
  celsius = ACCEPTANCE_TEMPERATURES.fetch(city)
  Riffer::Messages::Tool.new(
    "It is #{celsius} degrees Celsius in #{city}.",
    tool_call_id: tool_call.call_id,
    name: tool_call.name,
  )
end

# The JSON bodies of the requests the test sent, oldest first. WebMock counts
# identical requests under one entry, so each is repeated by its count.
def acceptance_request_bodies
  bodies = []
  WebMock::RequestRegistry.instance.requested_signatures.each do |signature, count|
    count.times { bodies << JSON.parse(signature.body) }
  end
  bodies
end

def acceptance_file(name)
  File.binread(File.join(ACCEPTANCE_FIXTURES_PATH, name))
end

# Runs one provider call. A stream is rebuilt into the Assistant message the
# Agent would build from it, so one assertion covers both modes.
def call_provider(provider, mode, **)
  return provider.generate_text(**) if mode == :generate

  assistant_from_stream(provider.stream_text(**).to_a)
end

def assistant_from_stream(events)
  text_done = events.grep(Riffer::StreamEvents::TextDone).last
  finish = events.grep(Riffer::StreamEvents::FinishReasonDone).last
  tool_calls = events.grep(Riffer::StreamEvents::ToolCallDone).map do |event|
    Riffer::Messages::Assistant::ToolCall.new(call_id: event.call_id, name: event.name, arguments: event.arguments)
  end

  Riffer::Messages::Assistant.new(
    text_done&.content || events.grep(Riffer::StreamEvents::TextDelta).map(&:content).join,
    tool_calls: tool_calls,
    reasoning: events.grep(Riffer::StreamEvents::ReasoningDone).map(&:part),
    token_usage: events.grep(Riffer::StreamEvents::TokenUsageDone).last&.token_usage,
    finish_reason: finish&.finish_reason,
    finish_reason_raw: finish&.raw_finish_reason,
  )
end

def run_agent(agent, mode, prompt, **)
  return agent.generate(prompt, **) if mode == :generate

  stream_agent(agent, prompt, **).last
end

# Agent#stream returns the Response as the enumerator's result, which only
# external iteration exposes: loop returns it when #next raises StopIteration.
def stream_agent(agent, prompt, **)
  enumerator = agent.stream(prompt, **)
  events = []
  response = loop { events << enumerator.next }
  [events, response]
end
