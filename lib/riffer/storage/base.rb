# frozen_string_literal: true

module Riffer::Storage
  class Base
    def initialize(**options)
      @options = options
    end

    def save(key, value)
      raise NotImplementedError, "Subclasses must implement #save"
    end

    def load(key)
      raise NotImplementedError, "Subclasses must implement #load"
    end

    def delete(key)
      raise NotImplementedError, "Subclasses must implement #delete"
    end
  end
end
