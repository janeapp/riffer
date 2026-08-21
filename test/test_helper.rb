# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/spec"

require "riffer"

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
  # Dotenv not available, skip loading .env file
end

# Disable AWS EC2 instance metadata service credential lookup in tests
# This prevents "Error retrieving instance profile credentials" messages
ENV["AWS_EC2_METADATA_DISABLED"] = "true"

# Configure VCR for recording HTTP interactions
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

# Clears the MCP registry between tests, retiring any in-flight discovery threads.
def clear_mcp_registry!
  Riffer::Mcp::Registry.registrations.each_key { |name| Riffer::Mcp::Registry.unregister(name) }
end

def install_in_memory_tracer_provider
  exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
  provider = OpenTelemetry::SDK::Trace::TracerProvider.new
  provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
  Riffer.config.tracing.backend = Riffer::Tracing::Otel.build(provider: provider)
  exporter
end
