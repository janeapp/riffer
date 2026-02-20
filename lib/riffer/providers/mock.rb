# frozen_string_literal: true
# rbs_inline: enabled

# Mock provider for mocking LLM responses in tests.
#
# No external gems required.
class Riffer::Providers::Mock < Riffer::Providers::Base
  # Array of recorded method calls for assertions.
  attr_reader :calls #: Array[Hash[Symbol, untyped]]

  # Initializes the mock provider.
  #
  #: (**untyped) -> void
  def initialize(**options)
    @responses = options[:responses] || []
    @current_index = 0
    @calls = []
    @stubbed_responses = []
  end

  # Stubs the next response from the provider.
  #
  # Can be called multiple times to queue responses.
  #
  #   provider.stub_response("Hello")
  #   provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
  #   provider.stub_response("Final response", token_usage: Riffer::TokenUsage.new(input_tokens: 10, output_tokens: 5))
  #
  #: (String, ?tool_calls: Array[Hash[Symbol, untyped]], ?token_usage: Riffer::TokenUsage?) -> void
  def stub_response(content, tool_calls: [], token_usage: nil)
    formatted_tool_calls = tool_calls.map.with_index do |tc, idx|
      Riffer::Messages::Assistant::ToolCall.new(
        id: tc[:id] || "mock_id_#{idx}",
        call_id: tc[:call_id] || tc[:id] || "mock_call_#{idx}",
        name: tc[:name],
        arguments: tc[:arguments].is_a?(String) ? tc[:arguments] : tc[:arguments].to_json
      )
    end
    @stubbed_responses << {role: "assistant", content: content, tool_calls: formatted_tool_calls, token_usage: token_usage}
  end

  # Clears all stubbed responses.
  #
  #: () -> void
  def clear_stubs
    @stubbed_responses = []
  end

  private

  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    web_search = options[:web_search]
    @calls << {messages: messages.map(&:to_h), model: model, **options.except(:web_search)}
    response = next_response
    response[:web_search] = web_search if web_search
    {response: response}
  end

  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def execute_generate(params)
    params[:response]
  end

  #: (untyped) -> Riffer::TokenUsage?
  def extract_token_usage(response)
    response[:token_usage]
  end

  #: (untyped, ?Riffer::TokenUsage?) -> Riffer::Messages::Assistant
  def extract_assistant_message(response, token_usage = nil)
    if response.is_a?(Hash)
      Riffer::Messages::Assistant.new(
        response[:content],
        tool_calls: response[:tool_calls] || [],
        token_usage: token_usage
      )
    else
      response
    end
  end

  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    response = params[:response]
    full_content = response[:content] || ""
    tool_calls = response[:tool_calls] || []
    token_usage = response[:token_usage]
    web_search = response[:web_search]

    if web_search
      yielder << Riffer::StreamEvents::WebSearchStatus.new("in_progress")
      yielder << Riffer::StreamEvents::WebSearchStatus.new("searching", query: "mock search query")
      yielder << Riffer::StreamEvents::WebSearchStatus.new("open_page", url: "https://example.com")
      yielder << Riffer::StreamEvents::WebSearchStatus.new("completed")
      yielder << Riffer::StreamEvents::WebSearchDone.new("mock search query", sources: [{title: "Example", url: "https://example.com"}])
    end

    unless full_content.empty?
      content_parts = full_content.split(". ").map { |part| part + (part.end_with?(".") ? "" : ".") }
      content_parts.each do |part|
        yielder << Riffer::StreamEvents::TextDelta.new(part + " ")
      end
    end

    tool_calls.each do |tc|
      yielder << Riffer::StreamEvents::ToolCallDelta.new(
        item_id: tc.id,
        name: tc.name,
        arguments_delta: tc.arguments
      )
      yielder << Riffer::StreamEvents::ToolCallDone.new(
        item_id: tc.id,
        call_id: tc.call_id,
        name: tc.name,
        arguments: tc.arguments
      )
    end

    yielder << Riffer::StreamEvents::TextDone.new(full_content)
    yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage) if token_usage
  end

  #: () -> Hash[Symbol, untyped]
  def next_response
    if @stubbed_responses.any?
      @stubbed_responses.shift
    elsif @responses[@current_index]
      response = @responses[@current_index]
      @current_index += 1
      response
    else
      {role: "assistant", content: "Mock response"}
    end
  end
end
