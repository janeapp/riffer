# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/spec"

require "riffer"
require "riffer/testing/minitest"

require "vcr"
require "webmock/minitest"

# Tracing tests assert real spans via the SDK's in-memory exporter; the
# no-OTEL CI lane excludes the gem to prove riffer's null fallback.
OTEL_SDK_AVAILABLE = begin
  require "opentelemetry-sdk"
  true
rescue LoadError
  false
end

begin
  require "dotenv"
  Dotenv.load
rescue LoadError
  nil
end

# The AWS SDK otherwise probes EC2 instance metadata for credentials and logs errors.
ENV["AWS_EC2_METADATA_DISABLED"] = "true"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri body],
  }

  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { ENV.fetch("ANTHROPIC_API_KEY", "test_api_key") }
  config.filter_sensitive_data("<AWS_BEDROCK_API_TOKEN>") { ENV.fetch("AWS_BEDROCK_API_TOKEN", "test_api_token") }
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV.fetch("OPENAI_API_KEY", "test_api_key") }
  config.filter_sensitive_data("<AZURE_OPENAI_API_KEY>") { ENV.fetch("AZURE_OPENAI_API_KEY", "test_api_key") }
  config.filter_sensitive_data("<AZURE_OPENAI_ENDPOINT>") { ENV.fetch("AZURE_OPENAI_ENDPOINT", "https://test.openai.azure.com/") }
  config.filter_sensitive_data("<GEMINI_API_KEY>") { ENV.fetch("GEMINI_API_KEY", "test_api_key") }
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") { ENV.fetch("OPENROUTER_API_KEY", "test_api_key") }
  config.filter_sensitive_data("<AWS_TEST_IMAGE_S3_URI>") do
    ENV.fetch("AWS_TEST_IMAGE_S3_URI", "s3://riffer-test-bucket/super-secret-image.png")
  end
  config.filter_sensitive_data("<AWS_TEST_DOCUMENT_S3_URI>") do
    ENV.fetch("AWS_TEST_DOCUMENT_S3_URI", "s3://riffer-test-bucket/super-secret-document.pdf")
  end
end

SKILLS_FIXTURES_PATH = File.expand_path("fixtures/skills", __dir__)

def clear_mcp_registry!
  Riffer::Mcp::Registry.registrations.each_key { |name| Riffer::Mcp::Registry.unregister(name) }
end

def assert_round_trips(object)
  hash = object.to_h
  parameters = object.class.instance_method(:initialize).parameters
  keywords = parameters.filter_map { |kind, name| name if kind in :key | :keyreq }
  # A fixture that doesn't populate a newly added attribute must fail rather than skip it silently.
  missing = keywords - hash.keys

  expect(missing).must_be_empty "#{object.class}#to_h omits #{missing.inspect}; populate them in the fixture"

  reloaded = object.class.from_hash(JSON.parse(JSON.generate(hash), symbolize_names: true))

  expect(reloaded.to_h).must_equal hash
end

def install_in_memory_tracer_provider
  exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  provider = OpenTelemetry::SDK::Trace::TracerProvider.new
  provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
  Riffer.config.tracing.backend = Riffer::Tracing::Otel.build(provider: provider)
  exporter
end
