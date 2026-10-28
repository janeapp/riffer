# frozen_string_literal: true

require "test_helper"
require "googleauth"

# Acceptance cassettes only replay. To record against the live APIs, set
# RIFFER_RECORD to a VCR record mode: "once" records missing cassettes, "all"
# re-records every cassette the run touches.
ACCEPTANCE_RECORD_MODE = ENV.fetch("RIFFER_RECORD", "none").to_sym

ACCEPTANCE_FIXTURES_PATH = File.expand_path("fixtures", __dir__)

ACCEPTANCE_CATALOG_PATH = File.join(ACCEPTANCE_FIXTURES_PATH, "catalog.json")

ACCEPTANCE_MODES = %i[generate stream].freeze

# Every acceptance file runs against each provider here unless it excludes it,
# so a new provider joins every feature by default. An entry holds what the
# tests can't derive: riffer passes model options and web_search options
# through as-is, so their names are the provider's own.
ACCEPTANCE_PROVIDERS = {
  gemini: {
    model: "gemini-3.5-flash-lite",
    max_tokens_option: :maxOutputTokens,
    web_search_options: { timeRangeFilter: { startTime: "2026-01-01T00:00:00Z", endTime: "2026-10-22T00:00:00Z" } },
    configure: -> { Riffer.config.gemini.api_key = ENV.fetch("GEMINI_API_KEY", "test_api_key") },
    break_credentials: -> { Riffer.config.gemini.api_key = "invalid-api-key" },
    reset: -> { Riffer.config.gemini.api_key = nil },
  },
  google_cloud: {
    model: "gemini-3.5-flash-lite",
    max_tokens_option: :maxOutputTokens,
    web_search_options: { timeRangeFilter: { startTime: "2026-01-01T00:00:00Z", endTime: "2026-10-22T00:00:00Z" } },
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

def configure_invalid_acceptance_credentials(provider_name)
  acceptance_setting(provider_name, :break_credentials).call
end

def reset_acceptance_provider(provider_name)
  acceptance_setting(provider_name, :reset).call
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
