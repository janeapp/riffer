# frozen_string_literal: true

module Riffer::Agents::Providers
  class Factory
    class << self
      def build(model_string, **options)
        provider_name, model_name = parse_model_string(model_string)

        case provider_name
        when "openai"
          build_openai(model_name, **options)
        when "test"
          Riffer::Agents::Providers::Test.new(**options)
        else
          raise ArgumentError, "Unknown provider: #{provider_name}"
        end
      end

      private

      def parse_model_string(model_string)
        parts = model_string.split("/", 2)
        if parts.size == 2
          [parts[0], parts[1]]
        else
          raise ArgumentError, "Model string must be in format 'provider/model', got: #{model_string}"
        end
      end

      def build_openai(model_name, **options)
        api_key = options[:api_key] || Riffer.config.openai_api_key
        raise ArgumentError, "OpenAI API key is required. Set it via Riffer.configure or pass :api_key option" if api_key.nil? || api_key.empty?

        Riffer::Agents::Providers::OpenAI.new(api_key: api_key, **options.except(:api_key))
      end
    end
  end
end
