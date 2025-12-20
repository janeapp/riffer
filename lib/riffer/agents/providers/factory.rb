# frozen_string_literal: true

module Riffer::Agents::Providers
  class Factory
    class << self
      def build(model_string, **options)
        provider_name, _model_name = parse_model_string(model_string)

        case provider_name
        when "openai"
          Riffer::Agents::Providers::OpenAI.new(**options)
        when "test"
          Riffer::Agents::Providers::Test.new(**options)
        else
          raise ArgumentError, "Unknown provider: #{provider_name}"
        end
      end

      private

      def parse_model_string(model_string)
        parts = model_string.split("/", 2)

        raise ArgumentError, "Model string must be in format 'provider/model', got: #{model_string}" unless parts.size == 2

        parts
      end
    end
  end
end
