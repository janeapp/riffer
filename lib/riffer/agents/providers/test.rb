# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class Test < Base
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

        def generate_text(messages:)
          @calls << {messages: messages}
          response = @stubbed_response || @responses[@current_index] || {role: "assistant", content: "Test response"}
          @current_index += 1
          response
        end

        def stream_text(messages:)
          @calls << {messages: messages}
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
  end
end
