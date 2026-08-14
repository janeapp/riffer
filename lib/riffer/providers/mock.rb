# frozen_string_literal: true
# rbs_inline: enabled

# Mock provider for mocking LLM responses in tests; no external gems required.
class Riffer::Providers::Mock < Riffer::Providers::Base
  # @rbs @responses: Array[Hash[Symbol, untyped]]
  # @rbs @current_index: Integer
  # @rbs @stubbed_responses: Array[Hash[Symbol, untyped]]

  # Returns the skill adapter for the mock model — XML when the model name
  # contains +claude+ (mirroring a real Claude provider), else Markdown.
  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(model = nil)
    return Riffer::Skills::XmlAdapter if model&.include?("claude")

    Riffer::Skills::MarkdownAdapter
  end

  # The GenAI semconv well-known provider name.
  #--
  #: () -> String
  def self.semconv_provider_name
    "mock"
  end

  # Array of recorded method calls for assertions.
  attr_reader :calls #: Array[Hash[Symbol, untyped]]

  # +responses:+ pre-configures canned responses (same shape as
  # +#stub_response+) for standalone use; agent tests queue responses on
  # <tt>agent.provider</tt> via +#stub_response+ instead.
  #
  #   Riffer::Providers::Mock.new(responses: [
  #     {content: "", tool_calls: [{name: "tool_a", arguments: "{}"}]},
  #     {content: "Final answer"}
  #   ])
  #
  #--
  #: (?responses: Array[Hash[Symbol, untyped]]) -> void
  def initialize(responses: [])
    super()
    @responses = responses.map { |r| normalize_response(r) }
    @current_index = 0
    @calls = []
    @stubbed_responses = []
  end

  # Stubs the next response; call repeatedly to queue several. +finish_reason+
  # defaults to +:tool_calls+ when tool calls are present, else +:stop+.
  #
  #   provider.stub_response("Hello")
  #   provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
  #   provider.stub_response("Final response",
  #                          token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 10, output_tokens: 5))
  #   provider.stub_response("Truncated...", finish_reason: :length)
  #
  #--
  #: (String, ?tool_calls: Array[Hash[Symbol, untyped]], ?token_usage: Riffer::Providers::TokenUsage?, ?finish_reason: Symbol?) -> void
  def stub_response(content, tool_calls: [], token_usage: nil, finish_reason: nil)
    @stubbed_responses << normalize_response(
      content: content,
      tool_calls: tool_calls,
      token_usage: token_usage,
      finish_reason: finish_reason,
    )
  end

  # Clears all stubbed responses.
  #
  #--
  #: () -> void
  def clear_stubs
    @stubbed_responses = []
  end

  private

  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def normalize_response(response)
    formatted_tool_calls = (response[:tool_calls] || []).map.with_index do |tc, idx|
      next tc if tc.is_a?(Riffer::Messages::Assistant::ToolCall)

      Riffer::Messages::Assistant::ToolCall.new(
        call_id: tc[:call_id] || tc[:id] || "mock_call_#{idx}",
        name: tc[:name],
        arguments: tc[:arguments].is_a?(String) ? tc[:arguments] : tc[:arguments].to_json,
      )
    end
    {
      role: response[:role] || "assistant",
      content: response[:content] || "",
      tool_calls: formatted_tool_calls,
      token_usage: response[:token_usage],
      finish_reason: response[:finish_reason] || (formatted_tool_calls.empty? ? :stop : :tool_calls),
    }
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    web_search = options[:web_search]
    @calls << { messages: messages.map(&:to_h), model: model, **options.except(:web_search) }
    response = next_response
    response[:web_search] = web_search if web_search
    { response: response }
  end

  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def execute_generate(params)
    params[:response]
  end

  #--
  #: (untyped) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    usage = response[:token_usage]
    usage && apply_pricing(usage)
  end

  #--
  #: (untyped) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    return nil unless response.is_a?(Hash)

    reason = response[:finish_reason]
    reason ? Riffer::Providers::FinishReason.new(reason: reason) : nil
  end

  #--
  #: (untyped) -> String
  def extract_content(response)
    response.is_a?(Hash) ? (response[:content] || "") : response.content
  end

  #--
  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    response.is_a?(Hash) ? (response[:tool_calls] || []) : response.tool_calls
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
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
      yielder << Riffer::StreamEvents::WebSearchDone.new(
        "mock search query",
        sources: [{ title: "Example", url: "https://example.com" }],
      )
    end

    unless full_content.empty?
      content_parts = full_content.split(". ").map { |part| part + (part.end_with?(".") ? "" : ".") }
      content_parts.each do |part|
        yielder << Riffer::StreamEvents::TextDelta.new("#{part} ")
      end
    end

    tool_calls.each do |tc|
      yielder << Riffer::StreamEvents::ToolCallDelta.new(
        item_id: tc.call_id,
        name: tc.name,
        arguments_delta: tc.arguments,
      )
      yielder << Riffer::StreamEvents::ToolCallDone.new(
        item_id: tc.call_id,
        call_id: tc.call_id,
        name: tc.name,
        arguments: tc.arguments,
      )
    end

    yielder << Riffer::StreamEvents::TextDone.new(full_content)
    yield_finish_reason(yielder, extract_finish_reason(response))
    yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: apply_pricing(token_usage)) if token_usage
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def next_response
    if @stubbed_responses.any?
      @stubbed_responses.shift
    elsif @current_index < @responses.size
      response = @responses[@current_index]
      @current_index += 1
      response
    else
      normalize_response(content: "Mock response")
    end
  end
end
