# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class Test < Base
        def initialize(**options)
          super(api_key: nil, **options)
          @responses = options[:responses] || []
          @current_index = 0
        end

        def chat(messages:, model:, **options)
          response = @responses[@current_index] || {role: "assistant", content: "Test response"}
          @current_index += 1
          response
        end
      end
    end
  end
end
