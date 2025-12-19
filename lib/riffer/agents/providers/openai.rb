# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class OpenAI < Base
        def initialize(api_key: nil, **options)
          super
          @api_key ||= ENV["OPENAI_API_KEY"]
        end

        def chat(messages:, model:, **options)
          # Implementation will use langchainrb for OpenAI
          {role: "assistant", content: "OpenAI provider response"}
        end
      end
    end
  end
end
