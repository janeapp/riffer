# frozen_string_literal: true

module Riffer::Guardrails
  class Base
    attr_reader :action

    def initialize(action: :mutate)
      @action = action
    end

    def process_input(content)
      content
    end

    def process_output(content)
      content
    end
  end
end
