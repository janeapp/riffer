# frozen_string_literal: true

module Riffer::Messages
  class User < Base
    def initialize(content)
      raise ArgumentError, "User message content cannot be nil" if content.nil?
      raise ArgumentError, "User message content cannot be empty" if content.respond_to?(:strip) && content.strip.empty?

      super
    end

    def role
      "user"
    end
  end
end
