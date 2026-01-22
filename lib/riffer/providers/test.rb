# frozen_string_literal: true

# Test provider for mocking LLM responses in tests.
#
# No external gems required.
class Riffer::Providers::Test < Riffer::Providers::Base
  # Array of recorded method calls for assertions.
  #
  # Returns Array of Hash.
  attr_reader :calls

  # Initializes the test provider.
  #
  # options:: Hash - optional configuration
  #
  # Use +:responses+ to pre-configure responses.
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
  # content:: String - the response content
  # tool_calls:: Array of Hash - optional tool calls to include
  #
  #   provider.stub_response("Hello")
  #   provider.stub_response("", tool_calls: [{name: "my_tool", arguments: '{"key":"value"}'}])
  #   provider.stub_response("Final response")
  #
  def stub_response(content, tool_calls: [])
    formatted_tool_calls = tool_calls.map.with_index do |tc, idx|
      {
        id: tc[:id] || "test_id_#{idx}",
        call_id: tc[:call_id] || tc[:id] || "test_call_#{idx}",
        name: tc[:name],
        arguments: tc[:arguments].is_a?(String) ? tc[:arguments] : tc[:arguments].to_json
      }
    end
    @stubbed_responses << {role: "assistant", content: content, tool_calls: formatted_tool_calls}
  end

  # Clears all stubbed responses.
  def clear_stubs
    @stubbed_responses = []
  end

  private

  def next_response
    if @stubbed_responses.any?
      @stubbed_responses.shift
    elsif @responses[@current_index]
      response = @responses[@current_index]
      @current_index += 1
      response
    else
      {role: "assistant", content: "Test response"}
    end
  end

  def perform_generate_text(messages, model: nil, **options)
    @calls << {messages: messages.map(&:to_h), model: model, **options}
    response = next_response

    if response.is_a?(Hash)
      Riffer::Messages::Assistant.new(response[:content], tool_calls: response[:tool_calls] || [])
    else
      response
    end
  end

  def perform_stream_text(messages, model: nil, **options)
    @calls << {messages: messages.map(&:to_h), model: model, **options}
    response = next_response
    Enumerator.new do |yielder|
      full_content = response[:content] || ""
      tool_calls = response[:tool_calls] || []

      unless full_content.empty?
        content_parts = full_content.split(". ").map { |part| part + (part.end_with?(".") ? "" : ".") }
        content_parts.each do |part|
          yielder << Riffer::StreamEvents::TextDelta.new(part + " ")
        end
      end

      tool_calls.each do |tc|
        yielder << Riffer::StreamEvents::ToolCallDelta.new(
          item_id: tc[:id],
          name: tc[:name],
          arguments_delta: tc[:arguments]
        )
        yielder << Riffer::StreamEvents::ToolCallDone.new(
          item_id: tc[:id],
          call_id: tc[:call_id],
          name: tc[:name],
          arguments: tc[:arguments]
        )
      end

      yielder << Riffer::StreamEvents::TextDone.new(full_content)
    end
  end
end
