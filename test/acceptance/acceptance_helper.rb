# frozen_string_literal: true

require "test_helper"
require "googleauth"

# Acceptance cassettes only replay. To record against the live APIs, set
# RIFFER_RECORD to a VCR record mode: "once" records missing cassettes, "all"
# re-records every cassette the run touches.
ACCEPTANCE_RECORD_MODE = ENV.fetch("RIFFER_RECORD", "none").to_sym

ACCEPTANCE_FIXTURES_PATH = File.expand_path("fixtures", __dir__)

ACCEPTANCE_MODELS = {
  gemini: "gemini-3.5-flash-lite",
  google_cloud: "gemini-3.5-flash-lite",
}.freeze

ACCEPTANCE_MODES = %i[generate stream].freeze

# Riffer passes model options through as-is, so each provider names its
# output token limit its own way.
ACCEPTANCE_MAX_TOKENS_OPTION = {
  gemini: :maxOutputTokens,
  google_cloud: :maxOutputTokens,
}.freeze

def acceptance_cassette(name, &)
  VCR.use_cassette("acceptance/#{name}", record: ACCEPTANCE_RECORD_MODE, &)
end

def configure_acceptance_provider(provider_name)
  case provider_name
  when :gemini
    Riffer.config.gemini.api_key = ENV.fetch("GEMINI_API_KEY", "test_api_key")
  when :google_cloud
    Riffer.config.google_cloud.project_id = ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project")
    Riffer.config.google_cloud.credentials = Google::Auth::BearerTokenCredentials.new(
      token: ENV.fetch("GOOGLE_CLOUD_ACCESS_TOKEN", "test_access_token"),
    )
  else
    raise ArgumentError, "No acceptance setup for #{provider_name.inspect}"
  end
end

def configure_invalid_acceptance_credentials(provider_name)
  case provider_name
  when :gemini
    Riffer.config.gemini.api_key = "invalid-api-key"
  when :google_cloud
    Riffer.config.google_cloud.credentials = Google::Auth::BearerTokenCredentials.new(token: "invalid-access-token")
  else
    raise ArgumentError, "No acceptance setup for #{provider_name.inspect}"
  end
end

def reset_acceptance_provider(provider_name)
  case provider_name
  when :gemini
    Riffer.config.gemini.api_key = nil
  when :google_cloud
    Riffer.config.google_cloud.project_id = nil
    Riffer.config.google_cloud.credentials = nil
  end
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
