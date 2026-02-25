# frozen_string_literal: true
# rbs_inline: enabled

# OpenAI provider for GPT models.
#
# Requires the +openai+ gem to be installed.
class Riffer::Providers::OpenAI < Riffer::Providers::Base
  WEB_SEARCH_TOOL_TYPE = "web_search_preview" #: String

  # Initializes the OpenAI provider.
  #
  #: (**untyped) -> void
  def initialize(**options)
    depends_on "openai"

    api_key = options.fetch(:api_key, Riffer.config.openai.api_key)
    @client = ::OpenAI::Client.new(api_key: api_key, **options.except(:api_key))
  end

  private

  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    reasoning = options[:reasoning]
    tools = options[:tools]
    structured_output = options[:structured_output]
    web_search = options[:web_search]

    params = {
      input: convert_messages_to_openai_format(messages),
      model: model,
      reasoning: reasoning && {
        effort: reasoning,
        summary: "auto"
      },
      **options.except(:reasoning, :tools, :structured_output, :web_search)
    }

    openai_tools = []
    openai_tools.concat(tools.map { |t| convert_tool_to_openai_format(t) }) if tools && !tools.empty?

    if web_search
      web_search_tool = {type: WEB_SEARCH_TOOL_TYPE}
      web_search_tool.merge!(web_search) if web_search.is_a?(Hash)
      openai_tools << web_search_tool
    end

    if structured_output
      params[:text] = {
        format: {
          type: "json_schema",
          name: "response",
          schema: structured_output.json_schema,
          strict: true
        }
      }
    end

    params[:tools] = openai_tools unless openai_tools.empty?

    params.compact
  end

  #: (Hash[Symbol, untyped]) -> OpenAI::Models::Responses::Response
  def execute_generate(params)
    @client.responses.create(params)
  end

  #: (OpenAI::Models::Responses::Response) -> Riffer::TokenUsage?
  def extract_token_usage(response)
    usage = response.usage
    return nil unless usage

    Riffer::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens
    )
  end

  #: (OpenAI::Models::Responses::Response) -> String
  def extract_content(response)
    text_content = ""

    response.output.each do |item|
      if item.type == :message
        text_block = item.content&.find { |c| c.type == :output_text }
        text_content = text_block&.text || "" if text_block
      end
    end

    text_content
  end

  #: (OpenAI::Models::Responses::Response) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    tool_calls = []

    response.output.each do |item|
      if item.type == :function_call
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          id: item.id,
          call_id: item.call_id,
          name: item.name,
          arguments: item.arguments
        )
      end
    end

    tool_calls
  end

  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    current_state = {
      tool_info: {}
    }

    stream = @client.responses.stream(params)
    stream.each do |event|
      case event.type
      when :"response.output_item.added"
        handle_output_item_added_function_call(event, state: current_state, yielder: yielder) if event.item&.type == :function_call
      when :"response.output_text.delta"
        handle_output_text_delta(event, state: current_state, yielder: yielder)
      when :"response.output_text.done"
        handle_output_text_done(event, state: current_state, yielder: yielder)
      when :"response.reasoning_summary_text.delta"
        handle_reasoning_summary_text_delta(event, state: current_state, yielder: yielder)
      when :"response.reasoning_summary_text.done"
        handle_reasoning_summary_text_done(event, state: current_state, yielder: yielder)
      when :"response.function_call_arguments.delta"
        handle_function_call_arguments_delta(event, state: current_state, yielder: yielder)
      when :"response.function_call_arguments.done"
        handle_function_call_arguments_done(event, state: current_state, yielder: yielder)
      when :"response.web_search_call.in_progress"
        handle_web_search_status(event, status: "in_progress", yielder: yielder)
      when :"response.web_search_call.searching"
        handle_web_search_status(event, status: "searching", yielder: yielder)
      when :"response.web_search_call.completed"
        handle_web_search_status(event, status: "completed", yielder: yielder)
      when :"response.output_item.done"
        handle_output_item_done_web_search(event, yielder: yielder) if event.item&.type == :web_search_call
      when :"response.completed"
        handle_response_completed(event, state: current_state, yielder: yielder)
      end
    end
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_output_item_added_function_call(event, state:, yielder:)
    state[:tool_info][event.item.id] = {
      name: event.item.name,
      call_id: event.item.call_id
    }
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_output_text_delta(event, state:, yielder:)
    yielder << Riffer::StreamEvents::TextDelta.new(event.delta)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_output_text_done(event, state:, yielder:)
    yielder << Riffer::StreamEvents::TextDone.new(event.text)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_reasoning_summary_text_delta(event, state:, yielder:)
    yielder << Riffer::StreamEvents::ReasoningDelta.new(event.delta)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_reasoning_summary_text_done(event, state:, yielder:)
    yielder << Riffer::StreamEvents::ReasoningDone.new(event.text)
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_function_call_arguments_delta(event, state:, yielder:)
    tracked = state[:tool_info][event.item_id] || {}
    yielder << Riffer::StreamEvents::ToolCallDelta.new(
      item_id: event.item_id,
      name: tracked[:name],
      arguments_delta: event.delta
    )
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_function_call_arguments_done(event, state:, yielder:)
    tracked = state[:tool_info][event.item_id] || {}
    yielder << Riffer::StreamEvents::ToolCallDone.new(
      item_id: event.item_id,
      call_id: tracked[:call_id] || event.item_id,
      name: tracked[:name],
      arguments: event.arguments
    )
  end

  #: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_response_completed(event, state:, yielder:)
    usage = event.response&.usage
    return unless usage

    yielder << Riffer::StreamEvents::TokenUsageDone.new(
      token_usage: Riffer::TokenUsage.new(
        input_tokens: usage.input_tokens,
        output_tokens: usage.output_tokens
      )
    )
  end

  #: (untyped, status: String, yielder: Enumerator::Yielder) -> void
  def handle_web_search_status(_event, status:, yielder:)
    yielder << Riffer::StreamEvents::WebSearchStatus.new(status)
  end

  #: (untyped, yielder: Enumerator::Yielder) -> void
  def handle_output_item_done_web_search(event, yielder:)
    action = event.item.action
    case action
    when OpenAI::Models::Responses::ResponseFunctionWebSearch::Action::OpenPage
      # OpenPage carries a url but no query or sources, so it doesn't fit
      # WebSearchDone — emit as a status notification instead.
      yielder << Riffer::StreamEvents::WebSearchStatus.new("open_page", url: action.url)
    when OpenAI::Models::Responses::ResponseFunctionWebSearch::Action::Search
      sources = (action.sources || []).map { |s| {title: nil, url: s.url} }
      yielder << Riffer::StreamEvents::WebSearchDone.new(action.query, sources: sources)
    end
  end

  #: (Array[Riffer::Messages::Base]) -> Array[Hash[Symbol, untyped]]
  def convert_messages_to_openai_format(messages)
    messages.flat_map do |message|
      case message
      when Riffer::Messages::System
        {role: "developer", content: message.content}
      when Riffer::Messages::User
        if message.files.empty?
          {role: "user", content: message.content}
        else
          content = [{type: "input_text", text: message.content}]
          message.files.each { |file| content << convert_file_part_to_openai_format(file) }
          {role: "user", content: content}
        end
      when Riffer::Messages::Assistant
        convert_assistant_to_openai_format(message)
      when Riffer::Messages::Tool
        {
          type: "function_call_output",
          call_id: message.tool_call_id,
          output: message.content
        }
      end
    end
  end

  #: (Riffer::Messages::Assistant) -> (Hash[Symbol, untyped] | Array[Hash[Symbol, untyped]])
  def convert_assistant_to_openai_format(message)
    if message.tool_calls.empty?
      {role: "assistant", content: message.content}
    else
      items = []
      items << {type: "message", role: "assistant", content: message.content} if message.content && !message.content.empty?
      message.tool_calls.each do |tc|
        items << {
          type: "function_call",
          id: tc.id,
          call_id: tc.call_id || tc.id,
          name: tc.name,
          arguments: tc.arguments.is_a?(String) ? tc.arguments : tc.arguments.to_json
        }
      end
      items
    end
  end

  #: (Riffer::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_openai_format(file)
    if file.image?
      image_url = file.url? ? file.url : "data:#{file.media_type};base64,#{file.data}"
      {type: "input_image", image_url: image_url}
    else
      data_uri = "data:#{file.media_type};base64,#{file.data}"
      block = {type: "input_file", file_data: data_uri}
      block[:filename] = file.filename if file.filename
      block
    end
  end

  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_openai_format(tool)
    {
      type: "function",
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters_schema,
      strict: true
    }
  end
end
