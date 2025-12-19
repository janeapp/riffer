# frozen_string_literal: true

require "zeitwerk"
require_relative "riffer/version"

module Riffer
  class Error < StandardError; end
end

# Configure Zeitwerk autoloader for the Riffer namespace
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "openai" => "OpenAI",
  "sqlite_adapter" => "SqliteAdapter"
)
loader.setup
