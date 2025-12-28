# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI"
)
loader.setup

module Riffer
  # Base error for Riffer
  class Error < StandardError; end

  # Argument error for Riffer
  class ArgumentError < ::ArgumentError; end

  # Configuration and versioning methods for Riffer
  class << self
    # Returns the Riffer configuration
    # @return [Riffer::Config]
    def config
      @config ||= Config.new
    end

    # Yields the configuration for block-based setup
    # @yieldparam [Riffer::Config] config
    def configure
      yield config if block_given?
    end

    # Returns the gem version
    # @return [String]
    def version
      VERSION
    end
  end
end
