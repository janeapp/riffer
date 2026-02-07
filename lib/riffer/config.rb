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
  # Amazon Bedrock configuration (Struct with +api_token+ and +region+).
  attr_reader :amazon_bedrock #: untyped

  # Anthropic configuration (Struct with +api_key+).
  attr_reader :anthropic #: untyped

  # OpenAI configuration (Struct with +api_key+).
  attr_reader :openai #: untyped

  # Evals configuration (Struct with +judge_model+).
  attr_reader :evals #: untyped

  #: return: void
  def initialize
    @amazon_bedrock = Struct.new(:api_token, :region).new
    @anthropic = Struct.new(:api_key).new
    @openai = Struct.new(:api_key).new
    @evals = Struct.new(:judge_model).new
  end
end
