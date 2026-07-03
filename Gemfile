# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "irb"
gem "dotenv"
gem "guard"
gem "guard-shell"

# Tracing tests assert real spans via the SDK's in-memory exporter. Lives in a
# Gemfile group (not gemspec dev deps) so the no-OTEL CI lane can exclude it
# with BUNDLE_WITHOUT and prove the Null fallback.
group :opentelemetry do
  gem "opentelemetry-sdk", "~> 1.8"
end
