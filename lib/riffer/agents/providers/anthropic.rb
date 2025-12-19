# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class Anthropic < Base
        def initialize(api_key: nil, **options)
          super
          @api_key ||= ENV["ANTHROPIC_API_KEY"]
        end

        def chat(messages:, model:, **options)
          # Implementation will use langchainrb for Anthropic
          {role: "assistant", content: "Anthropic provider response"}
        end
      end
    end
  end
end
