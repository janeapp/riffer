# frozen_string_literal: true

module Riffer::Messages
  class System < Base
    def initialize(content)
      validate_content!(content)
      super
    end

    def role
      "system"
    end

    private

    def validate_content!(content)
      raise Riffer::Messages::InvalidInputError, "System message content cannot be nil" if content.nil?
      raise Riffer::Messages::InvalidInputError, "System message content cannot be empty" if content.respond_to?(:strip) && content.strip.empty?
    end
  end
end
