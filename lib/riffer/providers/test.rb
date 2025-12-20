# frozen_string_literal: true

module Riffer::Providers
  class Test < Base
    identifier "test"

    attr_reader :calls

    def initialize(**options)
      @responses = options[:responses] || []
      @current_index = 0
      @calls = []
      @stubbed_response = nil
    end

    def stub_response(content, tool_calls: [])
      @stubbed_response = {role: "assistant", content: content, tool_calls: tool_calls}
    end

    private

    def perform_generate_text(messages, model: nil)
      @calls << {messages: messages.map(&:to_h)}
      response = @stubbed_response || @responses[@current_index] || {role: "assistant", content: "Test response"}
      @current_index += 1

      if response.is_a?(Hash)
        Riffer::Messages::Assistant.new(response[:content], tool_calls: response[:tool_calls] || [])
      else
        response
      end
    end

    def perform_stream_text(messages, model: nil)
      @calls << {messages: messages.map(&:to_h)}
      response = @stubbed_response || @responses[@current_index] || {role: "assistant", content: "Test response"}
      @current_index += 1
      Enumerator.new do |yielder|
        content_parts = response[:content].split(". ").map { |part| part + (part.end_with?(".") ? "" : ".") }
        content_parts.each do |part|
          yielder << {role: "assistant", content: part + " "}
          sleep 0.5
        end
      end
    end
  end
end
