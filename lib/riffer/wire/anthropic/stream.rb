# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Turns decoded Messages API stream events (JSON hashes, symbol keys) into
# riffer stream events, accumulating the final message as it goes. Finish
# reason and token usage are left to the caller, read from #finish!, so it can
# price the usage.
class Riffer::Wire::Anthropic::Stream
  # @rbs @tools: Array[singleton(Riffer::Tool)]
  # @rbs @message: Hash[Symbol, untyped]
  # @rbs @partial_json: Hash[Integer, String]
  # @rbs @text: String?
  # @rbs @web_search_query: String?
  # @rbs @completed: bool

  #--
  #: (?tools: Array[singleton(Riffer::Tool)]) -> void
  def initialize(tools: [])
    @tools = tools
    @message = { content: [] }
    @partial_json = {}
    @text = nil
    @web_search_query = nil
    @completed = false
  end

  # Raises Riffer::Error on a stream +error+ event.
  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def handle(event, yielder)
    case event[:type]
    when "message_start" then start_message(event)
    when "content_block_start" then start_block(event)
    when "content_block_delta" then apply_delta(event, yielder)
    when "content_block_stop" then stop_block(event, yielder)
    when "message_delta" then apply_message_delta(event)
    when "message_stop" then stop_message(yielder)
    when "error" then raise_stream_error(event)
    end
  end

  # Raises Riffer::IncompleteStreamError when the stream ended without
  # +message_stop+.
  #--
  #: () -> Riffer::Wire::Anthropic::Response
  def finish!
    raise Riffer::IncompleteStreamError, "Anthropic stream ended without a message_stop event" unless @completed

    Riffer::Wire::Anthropic::Response.new(@message, tools: @tools)
  end

  private

  #--
  #: (Hash[Symbol, untyped]) -> void
  def start_message(event)
    content = [] #: Array[Hash[Symbol, untyped]]
    @message = event[:message].merge(content: content)
  end

  #--
  #: (Hash[Symbol, untyped]) -> void
  def start_block(event)
    index = event[:index]
    block = event[:content_block].dup
    @message[:content][index] = block

    case block[:type]
    when "text" then block[:text] = +block[:text].to_s
    when "thinking"
      block[:thinking] = +block[:thinking].to_s
      block[:signature] = block[:signature].to_s
    when "tool_use", "server_tool_use" then @partial_json[index] = +""
    end
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def apply_delta(event, yielder)
    index = event[:index]
    block = @message[:content][index]
    delta = event[:delta]

    case delta[:type]
    when "text_delta"
      block[:text] << delta[:text]
      # Mutating append avoids O(n^2) copying; the buffer reaches TextDone
      # only at message stop.
      (@text ||= +"") << delta[:text]
      yielder << Riffer::StreamEvents::TextDelta.new(delta[:text])
    when "input_json_delta"
      @partial_json[index] << delta[:partial_json]
      # server_tool_use input (web search) is not a riffer tool call.
      return unless block[:type] == "tool_use"

      yielder << Riffer::StreamEvents::ToolCallDelta.new(
        item_id: block[:id],
        name: Riffer::Wire::Anthropic.decode_tool_name(block[:name], tools: @tools),
        arguments_delta: delta[:partial_json],
      )
    when "thinking_delta"
      block[:thinking] << delta[:thinking]
      yielder << Riffer::StreamEvents::ReasoningDelta.new(delta[:thinking])
    when "signature_delta"
      block[:signature] = delta[:signature]
    end
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def stop_block(event, yielder)
    index = event[:index]
    block = @message[:content][index]

    case block[:type]
    when "tool_use"
      block[:input] = parse_input(index)
      yielder << Riffer::StreamEvents::ToolCallDone.new(
        item_id: block[:id],
        call_id: block[:id],
        name: Riffer::Wire::Anthropic.decode_tool_name(block[:name], tools: @tools),
        arguments: block[:input].to_json,
      )
    when "thinking", "redacted_thinking"
      part = Riffer::Wire::Anthropic::Response.reasoning_part(block) #: Riffer::Messages::Assistant::ReasoningPart
      yielder << Riffer::StreamEvents::ReasoningDone.new(part)
    when "server_tool_use"
      block[:input] = parse_input(index)
      return unless block[:name] == "web_search"

      @web_search_query = block[:input]["query"]
      yielder << Riffer::StreamEvents::WebSearchStatus.new("searching", query: @web_search_query)
    when "web_search_tool_result"
      yielder << Riffer::StreamEvents::WebSearchDone.new(@web_search_query || "", sources: web_search_sources(block))
      @web_search_query = nil
    end
  end

  #--
  #: (Hash[Symbol, untyped]) -> void
  def apply_message_delta(event)
    @message.merge!(event[:delta] || {})
    usage = event[:usage]
    # Usage counts are cumulative; a field the delta omits keeps its start value.
    @message[:usage] = (@message[:usage] || {}).merge(usage.compact) if usage
  end

  #--
  #: (Riffer::Providers::_EventSink) -> void
  def stop_message(yielder)
    @completed = true
    text = @text
    yielder << Riffer::StreamEvents::TextDone.new(text) if text
  end

  #--
  #: (Hash[Symbol, untyped]) -> void
  def raise_stream_error(event)
    error = event[:error] || {}
    raise Riffer::Error, "Anthropic stream error (#{error[:type]}): #{error[:message]}"
  end

  #--
  #: (Integer) -> Hash[String, untyped]
  def parse_input(index)
    json = @partial_json.delete(index).to_s
    json.empty? ? {} : JSON.parse(json)
  end

  # An error result carries an object, not a list, as its content.
  #--
  #: (Hash[Symbol, untyped]) -> Array[Hash[Symbol, String?]]
  def web_search_sources(block)
    content = block[:content]
    return [] unless content.is_a?(Array)

    content.filter_map do |item|
      { title: item[:title], url: item[:url] } if item[:type] == "web_search_result"
    end
  end
end
