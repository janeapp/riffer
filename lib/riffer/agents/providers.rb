# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class Base
        def initialize(api_key: nil, **options)
          @api_key = api_key
          @options = options
        end

        def chat(messages:, model:, **options)
          raise NotImplementedError, "Subclasses must implement #chat"
        end
      end
    end
  end
end
