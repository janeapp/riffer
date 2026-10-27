# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Providers::AnthropicCompatible::MessagesAPI::Stream
  # @rbs @tools: Array[singleton(Riffer::Tool)]
  # @rbs @message: Hash[Symbol, untyped]
  # @rbs @partial_json: Hash[Integer, String]
  # @rbs @web_search_query: String?
  # @rbs @completed: bool

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Messages::Assistant::ReasoningPart?
  def self.reasoning_part(block)
    format = Riffer::Providers::AnthropicCompatible::MessagesAPI::REASONING_FORMAT

    case block[:type]
    when "thinking"
      Riffer::Messages::Assistant::ReasoningPart.new(
        type: :text,
        text: block[:thinking],
        signature: block[:signature],
        format: format,
      )
    when "redacted_thinking"
      Riffer::Messages::Assistant::ReasoningPart.new(type: :encrypted, data: block[:data], format: format)
    end
  end

  #--
  #: (tools: Array[singleton(Riffer::Tool)]) -> void
  def initialize(tools:)
    @tools = tools
    @message = { content: [] }
    @partial_json = {}
    @web_search_query = nil
    @completed = false
  end

  # Raises Riffer::APIError on a stream +error+ event.
  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink, ?request_id: String?) -> void
  def handle(event, yielder, request_id: nil)
    case event[:type]
    when "message_start" then start_message(event)
    when "content_block_start" then start_block(event)
    when "content_block_delta" then apply_delta(event, yielder)
    when "content_block_stop" then stop_block(event, yielder)
    when "message_delta" then apply_message_delta(event)
    when "message_stop" then stop_message(yielder)
    when "error" then raise_stream_error(event, request_id)
    end
  end

  # The caller reads finish reason and usage from here so it can price the usage.
  #--
  #: () -> Hash[Symbol, untyped]
  def finish!
    raise Riffer::IncompleteStreamError, "Anthropic stream ended without a message_stop event" unless @completed

    @message
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
      yielder << Riffer::StreamEvents::TextDelta.new(delta[:text])
    when "input_json_delta"
      (@partial_json[index] ||= +"") << delta[:partial_json]
      # server_tool_use input (web search) is not a riffer tool call.
      return unless block[:type] == "tool_use"

      yielder << Riffer::StreamEvents::ToolCallDelta.new(
        item_id: block[:id],
        name: Riffer::Wire.decode_tool_name(block[:name], tools: @tools),
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
      raw = @partial_json.delete(index).to_s
      input = parse_input(raw)
      block[:input] = input if input
      yielder << Riffer::StreamEvents::ToolCallDone.new(
        item_id: block[:id],
        call_id: block[:id],
        name: Riffer::Wire.decode_tool_name(block[:name], tools: @tools),
        arguments: input ? input.to_json : raw,
      )
    when "thinking", "redacted_thinking"
      part = self.class.reasoning_part(block) #: Riffer::Messages::Assistant::ReasoningPart
      yielder << Riffer::StreamEvents::ReasoningDone.new(part)
    when "server_tool_use"
      block[:input] = parse_input(@partial_json.delete(index).to_s) || {}
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
    text = @message[:content].filter_map { |block| block[:text] if block[:type] == "text" }.join
    yielder << Riffer::StreamEvents::TextDone.new(text) unless text.empty?
  end

  #--
  #: (Hash[Symbol, untyped], String?) -> void
  def raise_stream_error(event, request_id)
    error = event[:error] || {}
    raise Riffer::APIError.new(
      "Anthropic stream error (#{error[:type]}): #{error[:message]}",
      body: event.to_json,
      request_id: request_id,
    )
  end

  # A response cut off by max_tokens can end a block mid-input, leaving JSON
  # that does not parse.
  #--
  #: (String) -> Hash[String, untyped]?
  def parse_input(raw)
    Riffer::Wire.parse_tool_arguments(raw)
  rescue JSON::ParserError
    nil
  end

  #--
  #: (Hash[Symbol, untyped]) -> Array[Hash[Symbol, String?]]
  def web_search_sources(block)
    content = block[:content]
    # An error result carries an object, not a list, as its content.
    return [] unless content.is_a?(Array)

    content.filter_map do |item|
      { title: item[:title], url: item[:url] } if item[:type] == "web_search_result"
    end
  end
end
