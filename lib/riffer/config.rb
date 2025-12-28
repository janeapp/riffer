# frozen_string_literal: true

# Configuration for the Riffer framework
#
# Provides configuration options for AI providers and other settings.
#
# @example Setting the OpenAI API key
#   Riffer.config.openai.api_key = "sk-..."
class Riffer::Config
  # OpenAI configuration
  # @return [Struct]
  attr_reader :openai

  # Initializes the configuration
  # @return [void]
  def initialize
    @openai = Struct.new(:api_key).new
  end
end
