# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class Test < Base
        attr_reader :calls

        def initialize(**options)
          super(api_key: nil, **options)
          @responses = options[:responses] || []
          @current_index = 0
          @calls = []
          @stubbed_response = nil
        end

        def stub_response(content, tool_calls: [])
          @stubbed_response = {role: "assistant", content: content, tool_calls: tool_calls}
        end

        def chat(messages:, model: nil, **options)
          # Track the call
          @calls << {messages: messages, model: model, options: options}

          # Return stubbed response if set, otherwise use responses array or default
          response = @stubbed_response || @responses[@current_index] || {role: "assistant", content: "Test response"}
          @current_index += 1
          response
        end
      end
    end
  end
end
