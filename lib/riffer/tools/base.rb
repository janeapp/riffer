# frozen_string_literal: true

module Riffer::Tools
  class Base
    attr_reader :name, :description

    def initialize(name:, description:, **options)
      raise ArgumentError, "Tool name is required, got: #{name.inspect}" if name.nil? || (name.respond_to?(:empty?) && name.empty?)
      raise ArgumentError, "Tool description is required, got: #{description.inspect}" if description.nil? || (description.respond_to?(:empty?) && description.empty?)

      @name = name
      @description = description
      @options = options
    end

    def call(**params)
      raise NotImplementedError, "Subclasses must implement #call"
    end

    def schema
      {
        name: @name,
        description: @description,
        parameters: parameters_schema
      }
    end

    private

    def parameters_schema
      {}
    end
  end
end
