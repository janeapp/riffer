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
  AzureOpenAI = Struct.new(:api_key, :endpoint, keyword_init: true)
  OpenAI = Struct.new(:api_key, keyword_init: true)
  Evals = Struct.new(:judge_model, keyword_init: true)

  # Amazon Bedrock configuration (Struct with +api_token+ and +region+).
  attr_reader :amazon_bedrock #: Riffer::Config::AmazonBedrock

  # Anthropic configuration (Struct with +api_key+).
  attr_reader :anthropic #: Riffer::Config::Anthropic

  # Azure OpenAI configuration (Struct with +api_key+ and +endpoint+).
  attr_reader :azure_openai #: Riffer::Config::AzureOpenAI

  # OpenAI configuration (Struct with +api_key+).
  attr_reader :openai #: Riffer::Config::OpenAI

  # Evals configuration (Struct with +judge_model+).
  attr_reader :evals #: Riffer::Config::Evals

  # Global tool runtime configuration (experimental).
  #
  # Accepts a Riffer::ToolRuntime subclass, a Riffer::ToolRuntime instance,
  # or a Proc. Defaults to <tt>Riffer::ToolRuntime::Inline.new</tt>.
  attr_reader :tool_runtime #: (singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)

  # Global agent runtime configuration (experimental).
  #
  # Accepts a Riffer::AgentRuntime subclass, a Riffer::AgentRuntime instance,
  # or a Proc. Defaults to +Riffer::AgentRuntime::Inline.new+.
  attr_reader :agent_runtime #: (singleton(Riffer::AgentRuntime) | Riffer::AgentRuntime | Proc)

  # Sets the global tool runtime.
  #
  # Raises +Riffer::ArgumentError+ if the value is not a valid runtime
  # (ToolRuntime subclass, ToolRuntime instance, or Proc).
  #
  #--
  #: ((singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)) -> void
  def tool_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::ToolRuntime) || value.is_a?(Riffer::ToolRuntime) || value.is_a?(Proc)
    raise Riffer::ArgumentError, "tool_runtime must be a Riffer::ToolRuntime subclass, instance, or a Proc" unless valid
    @tool_runtime = value
  end

  # Sets the global agent runtime.
  #
  # Raises +Riffer::ArgumentError+ if the value is not a valid runtime
  # (AgentRuntime subclass, AgentRuntime instance, or Proc).
  #
  #: ((singleton(Riffer::AgentRuntime) | Riffer::AgentRuntime | Proc)) -> void
  def agent_runtime=(value)
    valid = (value.is_a?(Class) && value < Riffer::AgentRuntime) || value.is_a?(Riffer::AgentRuntime) || value.is_a?(Proc)
    raise Riffer::ArgumentError, "agent_runtime must be a Riffer::AgentRuntime subclass, instance, or a Proc" unless valid
    @agent_runtime = value
  end

  #--
  #: () -> void
  def initialize
    @amazon_bedrock = AmazonBedrock.new
    @anthropic = Anthropic.new
    @azure_openai = AzureOpenAI.new
    @openai = OpenAI.new
    @evals = Evals.new
    @tool_runtime = Riffer::ToolRuntime::Inline.new
    @agent_runtime = Riffer::AgentRuntime::Inline.new
  end
end
