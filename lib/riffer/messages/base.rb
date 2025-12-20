# frozen_string_literal: true

module Riffer::Messages
  class Base
    attr_reader :content

    def initialize(content)
      @content = content
    end

    def to_h
      {role: role, content: content}
    end

    def role
      raise NotImplementedError, "Subclasses must implement #role"
    end
  end
end
