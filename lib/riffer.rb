# frozen_string_literal: true

require "zeitwerk"
require_relative "riffer/version"

module Riffer
  class Error < StandardError; end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config if block_given?
    end
  end
end

# Configure Zeitwerk autoloader for the Riffer namespace
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI"
)
loader.setup
