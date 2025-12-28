# frozen_string_literal: true

module Riffer::Messages
  class System < Base
    def initialize(content)
      raise ArgumentError, "System message content cannot be nil" if content.nil?
      raise ArgumentError, "System message content cannot be empty" if content.respond_to?(:strip) && content.strip.empty?

      super
    end

    def role
      "system"
    end
  end
end
