# frozen_string_literal: true

require "zeitwerk"

# Riffer is the main module for the Riffer AI framework.
#
# Provides configuration, error classes, and versioning for the gem.
#
# See Riffer::Config, Riffer::Agent, Riffer::Providers, and Riffer::Messages.
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI"
)
loader.setup

module Riffer
  # Base error class for Riffer.
  class Error < StandardError; end

  # Raised when invalid arguments are provided.
  class ArgumentError < ::ArgumentError; end

  # Raised when tool parameter validation fails.
  class ValidationError < Error; end

  class << self
    # Returns the Riffer configuration.
    #
    # Returns Riffer::Config.
    def config
      @config ||= Config.new
    end

    # Yields the configuration for block-based setup.
    #
    # Yields config (Riffer::Config) to the block.
    #
    #   Riffer.configure do |config|
    #     config.openai.api_key = ENV['OPENAI_API_KEY']
    #   end
    #
    def configure
      yield config if block_given?
    end

    # Returns the gem version.
    #
    # Returns String.
    def version
      VERSION
    end
  end
end
