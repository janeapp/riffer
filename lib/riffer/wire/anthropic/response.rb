# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Reads a Messages API response body: the JSON hash, symbol keys.
class Riffer::Wire::Anthropic::Response
  # @rbs @body: Hash[Symbol, untyped]
  # @rbs @tools: Array[singleton(Riffer::Tool)]

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Messages::Assistant::ReasoningPart?
  def self.reasoning_part(block)
    case block[:type]
    when "thinking"
      Riffer::Messages::Assistant::ReasoningPart.new(
        type: :text,
        text: block[:thinking],
        signature: block[:signature],
        format: Riffer::Wire::Anthropic::REASONING_FORMAT,
      )
    when "redacted_thinking"
      Riffer::Messages::Assistant::ReasoningPart.new(
        type: :encrypted,
        data: block[:data],
        format: Riffer::Wire::Anthropic::REASONING_FORMAT,
      )
    end
  end

  # +tools+ are the request's tools, used to map wire tool names back to
  # riffer tool names.
  #--
  #: (Hash[Symbol, untyped], ?tools: Array[singleton(Riffer::Tool)]) -> void
  def initialize(body, tools: [])
    @body = body
    @tools = tools
  end

  #--
  #: () -> String
  def content
    blocks.filter_map { |block| block[:text] if block[:type] == "text" }.join
  end

  #--
  #: () -> Array[Riffer::Messages::Assistant::ToolCall]
  def tool_calls
    blocks.filter_map do |block|
      next unless block[:type] == "tool_use"

      Riffer::Messages::Assistant::ToolCall.new(
        call_id: block[:id],
        name: Riffer::Wire::Anthropic.decode_tool_name(block[:name], tools: @tools),
        arguments: (block[:input] || {}).to_json,
      )
    end
  end

  #--
  #: () -> Array[Riffer::Messages::Assistant::ReasoningPart]
  def reasoning
    blocks.filter_map { |block| self.class.reasoning_part(block) }
  end

  # Unpriced; pricing is the provider's concern.
  #--
  #: () -> Riffer::Providers::TokenUsage?
  def token_usage
    usage = @body[:usage]
    return nil unless usage

    cache_write = usage[:cache_creation_input_tokens]
    cache_read = usage[:cache_read_input_tokens]

    Riffer::Providers::TokenUsage.new(
      # Anthropic's input_tokens excludes the cache buckets; TokenUsage's includes them.
      input_tokens: (usage[:input_tokens] || 0) + (cache_write || 0) + (cache_read || 0),
      output_tokens: usage[:output_tokens] || 0,
      cache_write_tokens: cache_write,
      cache_read_tokens: cache_read,
    )
  end

  #--
  #: () -> Riffer::Providers::FinishReason?
  def finish_reason
    raw = @body[:stop_reason]
    return nil unless raw

    Riffer::Providers::FinishReason.new(reason: Riffer::Wire::Anthropic::FINISH_REASONS.fetch(raw, :other), raw: raw)
  end

  private

  #--
  #: () -> Array[Hash[Symbol, untyped]]
  def blocks
    @body[:content] || []
  end
end
