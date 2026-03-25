# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config
  AmazonBedrock = Struct.new(:api_token, :region, keyword_init: true)
  Anthropic = Struct.new(:api_key, keyword_init: true)
  AzureOpenAI = Struct.new(:api_key, :endpoint, keyword_init: true)
  OpenAI = Struct.new(:api_key, keyword_init: true)
  Evals = Struct.new(:judge_model, keyword_init: true)

  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock

  attr_reader :anthropic #: Riffer::Config::Anthropic

  attr_reader :azure_openai #: Riffer::Config::AzureOpenAI

  attr_reader :openai #: Riffer::Config::OpenAI

  attr_reader :evals #: Riffer::Config::Evals

  attr_reader :tool_runtime #: (singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)

  #: ((singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)) -> void
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::ToolRuntime) || value.is_a?(Riffer::ToolRuntime) || value.is_a?(Proc)
    raise Riffer::ArgumentError, "tool_runtime must be a Riffer::ToolRuntime subclass, instance, or a Proc" unless valid
    @tool_runtime = value
  end

  #: () -> void
  def initialize
    @amazon_bedrock = AmazonBedrock.new
    @anthropic = Anthropic.new
    @azure_openai = AzureOpenAI.new
    @openai = OpenAI.new
    @evals = Evals.new
    @tool_runtime = Riffer::ToolRuntime::Inline.new
  end
end
