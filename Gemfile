# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "irb"
gem "dotenv"
gem "guard"
gem "guard-shell"

# Tracing and metrics tests assert real spans/metrics via the SDK's in-memory
# exporters. Lives in a Gemfile group (not gemspec dev deps) so the no-OTEL CI
# lane can exclude it with BUNDLE_WITHOUT and prove the Null fallbacks. The
# metrics SDK is a separate gem from the traces SDK.
group :opentelemetry do
  gem "opentelemetry-sdk", "~> 1.8"
  gem "opentelemetry-metrics-sdk", "~> 0.15"
end
