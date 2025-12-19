# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      class Base
        include Riffer::DependencyHelper

        def generate_text(messages:)
          raise NotImplementedError, "Subclasses must implement #generate_text"
        end

        def stream_text(messages:)
          raise NotImplementedError, "Subclasses must implement #stream_text"
        end
      end
    end
  end
end
