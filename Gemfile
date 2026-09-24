# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "anthropic", "~> 1.71.0"
gem "async", "~> 2.46"
gem "aws-sdk-bedrockruntime", "~> 1.85"
gem "dotenv"
gem "faraday", ">= 1.0"
gem "guard"
gem "guard-shell"
gem "io-event", "< 1.23"
gem "irb"
gem "mcp", "~> 1.5"
gem "minitest", "~> 6.0"
gem "openai", "~> 0.91.0"
gem "rake", "~> 13.0"
gem "rbs-inline", "~> 0.12"
gem "rubocop", require: false
gem "rubocop-minitest", require: false
gem "rubocop-performance", require: false
gem "rubocop-rake", require: false
gem "steep", "~> 2.1"
gem "vcr", "~> 6.0"
gem "webmock", "~> 3.26"

gem "kramdown"
gem "kramdown-parser-gfm"
# kramdown's rouge integration trips deprecation warnings on rouge 5.
gem "rouge", "~> 4.6"
gem "webrick"

# A Gemfile group (not a gemspec dev dep) so the no-OTEL CI lane can exclude it
# with BUNDLE_WITHOUT and prove the Null fallback.
group :opentelemetry do
  gem "opentelemetry-sdk", "~> 1.13"
end
