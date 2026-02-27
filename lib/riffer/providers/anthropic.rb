# frozen_string_literal: true
# rbs_inline: enabled

# Anthropic provider for Claude models via the Anthropic API.
#
# Requires the +anthropic+ gem to be installed.
#
# See https://github.com/anthropics/anthropic-sdk-ruby
class Riffer::Providers::Anthropic < Riffer::Providers::Base
  WEB_SEARCH_TOOL_TYPE = "web_search_20250305" #: String

  # Initializes the Anthropic provider.
  #
  #: (?api_key: String?, **untyped) -> void
  def initialize(api_key: nil, **options)
    depends_on "anthropic"

    api_key ||= Riffer.config.anthropic.api_key

    @client = Anthropic::Client.new(api_key: api_key, **options)
  end

  private

  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]
    web_search = options[:web_search]

    max_tokens = options.fetch(:max_tokens, 4096)

    params = {
      model: model,
      messages: partitioned_messages[:conversation],
      max_tokens: max_tokens,
      **options.except(:tools, :max_tokens, :structured_output, :web_search)
    }

    params[:system] = partitioned_messages[:system] if partitioned_messages[:system]

    anthropic_tools = []
    anthropic_tools.concat(tools.map { |t| convert_tool_to_anthropic_format(t) }) if tools && !tools.empty?

    if web_search
      web_search_tool = {type: WEB_SEARCH_TOOL_TYPE, name: "web_search"}
      web_search_tool.merge!(web_search) if web_search.is_a?(Hash)
      anthropic_tools << web_search_tool
    end

    if structured_output
      # Use strict schema to make optional fields nullable. Without this,
      # Anthropic may return empty strings or whitespace instead of null
      # for optional fields that the model has no value for.
      params[:output_config] = {
        format: {
          type: "json_schema",
          schema: structured_output.json_schema(strict: true)
        }
      }
    end

    params[:tools] = anthropic_tools unless anthropic_tools.empty?

    params
  end

  #: (Hash[Symbol, untyped]) -> Anthropic::Models::Message
  def execute_generate(params)
    @client.messages.create(**params)
  end

  #: (Anthropic::Models::Message) -> Riffer::TokenUsage?
  def extract_token_usage(response)
    usage = response.usage
    return nil unless usage

    Riffer::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens,
      cache_creation_tokens: usage.cache_creation_input_tokens,
      cache_read_tokens: usage.cache_read_input_tokens
    )
  end

  #: (Anthropic::Models::Message) -> String
  def extract_content(response)
    content_blocks = response.content
    return "" if content_blocks.nil? || content_blocks.empty?

    text_content = ""

    content_blocks.each do |block|
      text_content = block.text if block.type.to_s == "text"
    end

    text_content
  end

  #: (Anthropic::Models::Message) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    content_blocks = response.content
    return [] if content_blocks.nil? || content_blocks.empty?

    tool_calls = []

    content_blocks.each do |block|
      if block.type.to_s == "tool_use"
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          id: block.id,
          call_id: block.id,
          name: block.name,
          arguments: block.input.to_json
        )
      end
    end

    tool_calls
  end

  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    current_state = {
      text: nil,
      reasoning: nil,
      tool_call: nil,
      web_search_index: nil,
      web_search_json: nil,
      web_search_query: nil
    }

    stream = @client.messages.stream(**params)
    current_state[:stream] = stream

    stream.each do |event|
      case event
      when Anthropic::Models::RawContentBlockStartEvent
        handle_raw_content_block_start(event, state: current_state)
      when Anthropic::Models::RawContentBlockDeltaEvent
        handle_raw_content_block_delta(event, state: current_state)
      when Anthropic::Streaming::TextEvent
        handle_text_event(event, state: current_state, yielder: yielder)
      when Anthropic::Streaming::ThinkingEvent
        handle_thinking_event(event, state: current_state, yielder: yielder)
      when Anthropic::Streaming::InputJsonEvent
        handle_input_json_event(event, state: current_state, yielder: yielder)
      when Anthropic::Streaming::ContentBlockStopEvent
        block_type = event.content_block&.type.to_s
        handle_content_block_stop_text(event, state: current_state, yielder: yielder) if block_type == "text" && current_state[:text]
        handle_content_block_stop_tool_use(event, state: current_state, yielder: yielder) if block_type == "tool_use"
        handle_content_block_stop_thinking(event, state: current_state, yielder: yielder) if block_type == "thinking" && current_state[:reasoning]
        handle_content_block_stop_server_tool_use(event, state: current_state, yielder: yielder) if block_type == "server_tool_use"
        handle_content_block_stop_web_search_result(event, state: current_state, yielder: yielder) if block_type == "web_search_tool_result"
      when Anthropic::Streaming::MessageStopEvent
        handle_message_stop(event, state: current_state, yielder: yielder)
      end
    end
  end

  #: (untyped, state: Hash[Symbol, untyped]) -> void
  def handle_raw_content_block_start(event, state:)
    content_block = event.content_block
    if content_block.type.to_s == "server_tool_use" && content_block.name.to_s == "web_search"
      state[:web_search_index] = event.index
      state[:web_search_json] = ""
    end
  end

  #: (untyped, state: Hash[Symbol, untyped]) -> void
  def handle_raw_content_block_delta(event, state:)
    return unless state[:web_search_index] == event.index

    delta = event.delta
    state[:web_search_json] += delta.partial_json if delta.respond_to?(:partial_json)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_text_event(event, state:, yielder:)
    state[:text] ||= ""
    state[:text] += event.text
    yielder << Riffer::StreamEvents::TextDelta.new(event.text)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_thinking_event(event, state:, yielder:)
    state[:reasoning] ||= ""
    state[:reasoning] += event.thinking
    yielder << Riffer::StreamEvents::ReasoningDelta.new(event.thinking)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_input_json_event(event, state:, yielder:)
    if state[:tool_call].nil?
      state[:tool_call] = {id: nil, name: nil, arguments: ""}
    end
    state[:tool_call][:arguments] += event.partial_json
    yielder << Riffer::StreamEvents::ToolCallDelta.new(
      item_id: state[:tool_call][:id] || "pending",
      name: state[:tool_call][:name],
      arguments_delta: event.partial_json
    )
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_stop_tool_use(event, state:, yielder:)
    content_block = event.content_block
    arguments = content_block.input.is_a?(String) ? content_block.input : content_block.input.to_json
    yielder << Riffer::StreamEvents::ToolCallDone.new(
      item_id: content_block.id,
      call_id: content_block.id,
      name: content_block.name,
      arguments: arguments
    )
    state[:tool_call] = nil
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_stop_thinking(_event, state:, yielder:)
    yielder << Riffer::StreamEvents::ReasoningDone.new(state[:reasoning])
    state[:reasoning] = nil
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_stop_text(_event, state:, yielder:)
    yielder << Riffer::StreamEvents::TextDone.new(state[:text])
    state[:text] = nil
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_stop_server_tool_use(_event, state:, yielder:)
    return unless state[:web_search_json]

    input = JSON.parse(state[:web_search_json])
    state[:web_search_query] = input["query"]
    state[:web_search_index] = nil
    state[:web_search_json] = nil
    yielder << Riffer::StreamEvents::WebSearchStatus.new("searching", query: input["query"])
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_stop_web_search_result(event, state:, yielder:)
    content_block = event.content_block
    sources = (content_block.content || []).filter_map do |item|
      next unless item.type.to_s == "web_search_result"
      {title: item.title, url: item.url}
    end

    yielder << Riffer::StreamEvents::WebSearchDone.new(state[:web_search_query] || "", sources: sources)
    state[:web_search_query] = nil
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_message_stop(_event, state:, yielder:)
    final_message = state[:stream].accumulated_message
    if final_message&.usage
      usage = final_message.usage
      yielder << Riffer::StreamEvents::TokenUsageDone.new(
        token_usage: Riffer::TokenUsage.new(
          input_tokens: usage.input_tokens,
          output_tokens: usage.output_tokens,
          cache_creation_tokens: usage.cache_creation_input_tokens,
          cache_read_tokens: usage.cache_read_input_tokens
        )
      )
    end
  end

  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_prompts = []
    conversation_messages = []

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_prompts << {type: "text", text: message.content}
      when Riffer::Messages::User
        if message.files.empty?
          conversation_messages << {role: "user", content: message.content}
        else
          content = [{type: "text", text: message.content}]
          message.files.each { |file| content << convert_file_part_to_anthropic_format(file) }
          conversation_messages << {role: "user", content: content}
        end
      when Riffer::Messages::Assistant
        conversation_messages << convert_assistant_to_anthropic_format(message)
      when Riffer::Messages::Tool
        conversation_messages << {
          role: "user",
          content: [{
            type: "tool_result",
            tool_use_id: message.tool_call_id,
            content: message.content
          }]
        }
      end
    end

    {
      system: system_prompts.empty? ? nil : system_prompts,
      conversation: conversation_messages
    }
  end

  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant_to_anthropic_format(message)
    content = []
    content << {type: "text", text: message.content} if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        type: "tool_use",
        id: tc.id || tc.call_id,
        name: tc.name,
        input: parse_tool_arguments(tc.arguments)
      }
    end

    {role: "assistant", content: content}
  end

  #: (Riffer::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_anthropic_format(file)
    type = file.image? ? "image" : "document"

    source = if file.url?
      {type: "url", url: file.url}
    else
      {type: "base64", media_type: file.media_type, data: file.data}
    end

    {type: type, source: source}
  end

  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_anthropic_format(tool)
    {
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters_schema(strict: true)
    }
  end
end
