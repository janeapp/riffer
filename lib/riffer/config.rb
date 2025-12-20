# frozen_string_literal: true

module Riffer
  class Config
    attr_reader :openai

    def initialize
      @openai = Struct.new(:api_key).new
    end
  end
end
