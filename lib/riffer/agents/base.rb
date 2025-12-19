# frozen_string_literal: true

module Riffer
  module Agents
    class Base
      attr_reader :name, :model, :provider

      def initialize(name:, model:, provider: nil, **options)
        @name = name
        @model = model
        @provider = provider
        @options = options
      end

      def call(input)
        raise NotImplementedError, "Subclasses must implement #call"
      end
    end
  end
end
