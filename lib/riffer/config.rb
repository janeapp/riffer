# frozen_string_literal: true
# rbs_inline: enabled

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
#   Riffer.config.evals.judge_model = "anthropic/claude-sonnet-4-20250514"
#
class Riffer::Config
  AmazonBedrock = Struct.new(:api_token, :region, keyword_init: true)
  Anthropic = Struct.new(:api_key, keyword_init: true)
  OpenAI = Struct.new(:api_key, keyword_init: true)
  Evals = Struct.new(:judge_model, keyword_init: true)

  # Amazon Bedrock configuration (Struct with +api_token+ and +region+).
  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock

  # Anthropic configuration (Struct with +api_key+).
  attr_reader :anthropic #: Riffer::Config::Anthropic

  # OpenAI configuration (Struct with +api_key+).
  attr_reader :openai #: Riffer::Config::OpenAI

  # Evals configuration (Struct with +judge_model+).
  attr_reader :evals #: Riffer::Config::Evals

  #: return: void
  def initialize
    @amazon_bedrock = AmazonBedrock.new
    @anthropic = Anthropic.new
    @openai = OpenAI.new
    @evals = Evals.new
  end
end
