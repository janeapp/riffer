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

# These identify the recording account (org, project and workspace ids, quota
# tiers, the Cloudflare cookie). No client reads them on replay.
ACCOUNT_RESPONSE_HEADERS = /
  \A(
    set-cookie |
    openai-(organization|project) |
    anthropic-(organization|workspace)-id |
    (anthropic|x)-ratelimit-.+
  )\z
/ix

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
  config.filter_sensitive_data("<GOOGLE_CLOUD_ACCESS_TOKEN>") do
    ENV.fetch("GOOGLE_CLOUD_ACCESS_TOKEN", "test_access_token")
  end
  config.filter_sensitive_data("<GOOGLE_CLOUD_PROJECT>") { ENV.fetch("GOOGLE_CLOUD_PROJECT", "test-project") }
  config.filter_sensitive_data("<OPENROUTER_API_KEY>") { ENV.fetch("OPENROUTER_API_KEY", "test_api_key") }

  config.before_record do |interaction|
    # A SigV4 recording carries the access key id and session token here.
    # Replay matches on method, URI and body only, so no recording needs them.
    interaction.request.headers.delete("Authorization")
    interaction.request.headers.delete("X-Amz-Security-Token")
    # Azure puts the resource name in Host; the URI already carries it as a placeholder.
    interaction.request.headers.delete("Host")
    interaction.response.headers.reject! { |name, _| name.match?(ACCOUNT_RESPONSE_HEADERS) }

    # Sensitive-data placeholders make the URI unparseable, so match the host as text.
    host = interaction.request.uri[%r{\Ahttps?://([^/:]+)}, 1].to_s
    aws_host = host.match?(/\.(amazonaws\.com(\.cn)?|api\.aws)\z/)
    # A credential fetch (STS, SSO, or the link-local container and instance
    # metadata endpoints) would record the credentials themselves.
    interaction.ignore! if (aws_host && !host.start_with?("bedrock-runtime.")) || host.start_with?("169.254.")
  end
end

SKILLS_FIXTURES_PATH = File.expand_path("fixtures/skills", __dir__)
REASONING_CATALOG_PATH = File.expand_path("fixtures/catalogs/reasoning.json", __dir__)

# A test that swaps in a fresh config goes through here so the suite keeps
# failing on deprecated calls; wrap an intentional one in allow_deprecations.
def reset_riffer_config!
  config = Riffer::Config.new
  config.deprecations = :raise
  Riffer.instance_variable_set(:@config, config)
end

reset_riffer_config!

def evaluator_subclass(&)
  Riffer::Deprecation.allow { Class.new(Riffer::Evals::Evaluator, &) }
end

def clear_mcp_registry!
  Riffer::Mcp::Registry.registrations.each_key { |name| Riffer::Mcp::Registry.unregister(name) }
end

def configure_mcp_credentials(credentials)
  allow_deprecations { Riffer.config.mcp.credentials = credentials }
end

def assert_round_trips(object, omitted: [])
  hash = object.to_h
  parameters = object.class.instance_method(:initialize).parameters
  keywords = parameters.filter_map { |kind, name| name if kind in :key | :keyreq }
  # A fixture that doesn't populate a newly added attribute must fail rather than skip it silently.
  missing = keywords - omitted - hash.keys

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
