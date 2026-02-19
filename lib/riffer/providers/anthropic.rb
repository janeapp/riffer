# frozen_string_literal: true
# rbs_inline: enabled

# Anthropic provider for Claude models via the Anthropic API.
#
# Requires the +anthropic+ gem to be installed.
#
# See https://github.com/anthropics/anthropic-sdk-ruby
class Riffer::Providers::Anthropic < Riffer::Providers::Base
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

    max_tokens = options.fetch(:max_tokens, 4096)

    params = {
      model: model,
      messages: partitioned_messages[:conversation],
      max_tokens: max_tokens,
      **options.except(:tools, :max_tokens)
    }

    params[:system] = partitioned_messages[:system] if partitioned_messages[:system]

    if tools && !tools.empty?
      params[:tools] = tools.map { |t| convert_tool_to_anthropic_format(t) }
    end

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

  #: (Anthropic::Models::Message, ?Riffer::TokenUsage?) -> Riffer::Messages::Assistant
  def extract_assistant_message(response, token_usage = nil)
    content_blocks = response.content
    raise Riffer::Error, "No content returned from Anthropic API" if content_blocks.nil? || content_blocks.empty?

    text_content = ""
    tool_calls = []

    content_blocks.each do |block|
      block_type = block.type.to_s
      case block_type
      when "text"
        text_content = block.text
      when "tool_use"
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          id: block.id,
          call_id: block.id,
          name: block.name,
          arguments: block.input.to_json
        )
      end
    end

    if text_content.empty? && tool_calls.empty?
      raise Riffer::Error, "No content returned from Anthropic API"
    end

    Riffer::Messages::Assistant.new(text_content, tool_calls: tool_calls, token_usage: token_usage)
  end

  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    current_state = {
      text: nil,
      reasoning: nil,
      tool_call: nil
    }

    stream = @client.messages.stream(**params)
    current_state[:stream] = stream

    stream.each do |event|
      case event
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
      when Anthropic::Streaming::MessageStopEvent
        handle_message_stop(event, state: current_state, yielder: yielder)
      end
    end
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
        conversation_messages << {role: "user", content: message.content}
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

  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_anthropic_format(tool)
    {
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters_schema
    }
  end
end
