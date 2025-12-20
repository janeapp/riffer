# frozen_string_literal: true

module Riffer
  class Config
    class OpenAIConfig
      attr_accessor :api_key

      def initialize
        @api_key = nil
      end
    end

    attr_reader :openai

    def initialize
      @openai = OpenAIConfig.new
    end
  end
end
