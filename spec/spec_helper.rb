# frozen_string_literal: true

require "riffer"
require "vcr"
require "webmock/rspec"

begin
  require "dotenv"
  Dotenv.load
rescue LoadError
  # Dotenv not available, skip loading .env file
end

# Configure VCR for recording HTTP interactions
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body]
  }

  # Filter sensitive data
  config.filter_sensitive_data("<OPENAI_API_KEY>") { ENV.fetch("OPENAI_API_KEY", "test_api_key") }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
