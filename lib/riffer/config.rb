# frozen_string_literal: true

# Configuration for the Riffer framework
#
# Provides configuration options for AI providers and other settings.
#
# @example Setting the OpenAI API key
#   Riffer.config.openai.api_key = "sk-..."
#
# @example Setting Amazon Bedrock configuration
#   Riffer.config.amazon_bedrock.region = "us-east-1"
#   Riffer.config.amazon_bedrock.api_token = "..."
class Riffer::Config
  # OpenAI configuration
  # @return [Struct]
  attr_reader :openai

  # Amazon Bedrock configuration
  # @return [Struct]
  attr_reader :amazon_bedrock

  # Initializes the configuration
  # @return [void]
  def initialize
    @openai = Struct.new(:api_key).new
    @amazon_bedrock = Struct.new(:api_token, :region).new
  end
end
