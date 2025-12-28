# frozen_string_literal: true

require "zeitwerk"

# :nodoc:
# Riffer is the main module for the Riffer AI framework.
#
# Provides configuration, error classes, and versioning for the gem.
#
# @see Riffer::Config
# @see Riffer::Agent
# @see Riffer::Providers
# @see Riffer::Messages
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "open_ai" => "OpenAI"
)
loader.setup

module Riffer
  # Base error for Riffer
  # @api public
  class Error < StandardError; end

  # Argument error for Riffer
  # @api public
  class ArgumentError < ::ArgumentError; end

  # Provides configuration and versioning methods for Riffer
  #
  # @!group Configuration
  class << self
    # Returns the Riffer configuration
    # @return [Riffer::Config]
    def config
      @config ||= Config.new
    end

    # Yields the configuration for block-based setup
    # @yieldparam config [Riffer::Config] the configuration object
    # @return [void]
    def configure
      yield config if block_given?
    end

    # Returns the gem version
    # @return [String] the version string
    def version
      VERSION
    end
  end
end
