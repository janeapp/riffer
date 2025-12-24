# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/spec"

require "riffer"

require "vcr"
require "webmock/minitest"

begin
  require "dotenv"
  Dotenv.load
rescue LoadError
  # Dotenv not available, skip loading .env file
end

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }

  # Filter sensitive data
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV.fetch("OPENAI_API_KEY", "test_api_key") }
end
