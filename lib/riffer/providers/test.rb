# frozen_string_literal: true

class Riffer::Providers::Test < Riffer::Providers::Base
  attr_reader :calls

  def initialize(**options)
    @responses = options[:responses] || []
    @current_index = 0
    @calls = []
    @stubbed_response = nil
    @stubbed_reasoning = nil
  end

  def stub_response(content, tool_calls: [], reasoning: nil)
    @stubbed_response = {role: "assistant", content: content, tool_calls: tool_calls}
    @stubbed_reasoning = reasoning
  end

  private

  def perform_generate_text(messages, model: nil, reasoning: nil)
    @calls << {messages: messages.map(&:to_h), model: model, reasoning: reasoning}
    response = @stubbed_response || @responses[@current_index] || {role: "assistant", content: "Test response"}
    @current_index += 1

    if response.is_a?(Hash)
      Riffer::Messages::Assistant.new(response[:content], tool_calls: response[:tool_calls] || [])
    else
      response
    end
  end

  def perform_stream_text(messages, model: nil, reasoning: nil)
    @calls << {messages: messages.map(&:to_h), model: model, reasoning: reasoning}
    response = @stubbed_response || @responses[@current_index] || {role: "assistant", content: "Test response"}
    @current_index += 1
    Enumerator.new do |yielder|
      if @stubbed_reasoning
        reasoning_parts = @stubbed_reasoning.split(". ").map { |part| part + (part.end_with?(".") ? "" : ".") }

        reasoning_parts.each do |part|
          yielder << Riffer::StreamEvents::ReasoningDelta.new(part + " ")
        end

        yielder << Riffer::StreamEvents::ReasoningDone.new(@stubbed_reasoning)
      end

      full_content = response[:content]
      content_parts = full_content.split(". ").map { |part| part + (part.end_with?(".") ? "" : ".") }

      content_parts.each do |part|
        yielder << Riffer::StreamEvents::TextDelta.new(part + " ")
      end

      yielder << Riffer::StreamEvents::TextDone.new(full_content)
    end
  end
end
