# frozen_string_literal: true

module Riffer::Agents::Providers
  class OpenAI < Base
    def initialize
      depends_on "openai"
    end

    private

    def perform_generate_text(messages)
      {role: "assistant", content: "OpenAI provider response"}
    end

    def perform_stream_text(messages)
      Enumerator.new do |yielder|
        yielder << {role: "assistant", content: "Streaming response part 1. "}
        sleep 1
        yielder << {role: "assistant", content: "Streaming response part 2. "}
        sleep 1
        yielder << {role: "assistant", content: "Streaming response part 3."}
      end
    end
  end
end
