# frozen_string_literal: true

# Configuration for the Riffer framework.
#
# Provides configuration options for AI providers and other settings.
#
#   Riffer.config.openai.api_key = "sk-..."
#
#   Riffer.config.amazon_bedrock.region = "us-east-1"
#   Riffer.config.amazon_bedrock.api_token = "..."
#
#   Riffer.config.anthropic.api_key = "sk-ant-..."
#
class Riffer::Config
  # Amazon Bedrock configuration (Struct with +api_token+ and +region+).
  #
  # Returns Struct.
  attr_reader :amazon_bedrock

  # Anthropic configuration (Struct with +api_key+).
  #
  # Returns Struct.
  attr_reader :anthropic

  # OpenAI configuration (Struct with +api_key+).
  #
  # Returns Struct.
  attr_reader :openai

  # Initializes the configuration.
  def initialize
    @amazon_bedrock = Struct.new(:api_token, :region).new
    @anthropic = Struct.new(:api_key).new
    @openai = Struct.new(:api_key).new
  end
end
