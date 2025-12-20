# frozen_string_literal: true

module Riffer
  class Config
    attr_accessor :openai_api_key

    def initialize
      @openai_api_key = nil
    end
  end
end
