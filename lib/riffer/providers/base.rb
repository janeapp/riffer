# frozen_string_literal: true

module Riffer::Providers
  class Base
    include Riffer::DependencyHelper
    include Riffer::Messages::Converter

    class << self
      def identifier(value = nil)
        return @identifier if value.nil?

        @identifier = value
      end

      def find_provider(identifier)
        ensure_providers_loaded

        provider = subclasses.find { |provider_class| provider_class.identifier == identifier }

        raise InvalidInputError, "Provider not found for identifier: #{identifier}" if provider.nil?

        provider
      end

      private

      def ensure_providers_loaded
        return if @providers_loaded

        Zeitwerk::Loader.eager_load_namespace(Riffer::Providers)

        @providers_loaded = true
      end
    end

    def generate_text(prompt: nil, system: nil, messages: nil, model: nil)
      validate_input!(prompt: prompt, system: system, messages: messages)
      raise InvalidInputError, "model is required" if model.nil?
      raise InvalidInputError, "model cannot be empty" if model.respond_to?(:strip) && model.strip.empty?
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
      validate_normalized_messages!(normalized_messages)
      perform_generate_text(normalized_messages, model: model)
    end

    def stream_text(prompt: nil, system: nil, messages: nil, model: nil)
      validate_input!(prompt: prompt, system: system, messages: messages)
      raise InvalidInputError, "model is required" if model.nil?
      raise InvalidInputError, "model cannot be empty" if model.respond_to?(:strip) && model.strip.empty?
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
      validate_normalized_messages!(normalized_messages)
      perform_stream_text(normalized_messages, model: model)
    end

    private

    def perform_generate_text(messages, model: nil)
      raise NotImplementedError, "Subclasses must implement #perform_generate_text"
    end

    def perform_stream_text(messages, model: nil)
      raise NotImplementedError, "Subclasses must implement #perform_stream_text"
    end

    def validate_input!(prompt:, system:, messages:)
      if messages.nil?
        raise InvalidInputError, "prompt is required when messages is not provided" if prompt.nil?
      else
        raise InvalidInputError, "cannot provide both prompt and messages" unless prompt.nil?
        raise InvalidInputError, "cannot provide both system and messages" unless system.nil?
      end
    end

    def validate_normalized_messages!(messages)
      has_user = messages.any? { |msg| msg.is_a?(Riffer::Messages::User) }
      raise InvalidInputError, "messages must include at least one user message" unless has_user
    end

    def normalize_messages(prompt:, system:, messages:)
      if messages
        return messages.map { |msg| convert_to_message_object(msg) }
      end

      result = []
      result << Riffer::Messages::System.new(system) if system
      result << Riffer::Messages::User.new(prompt)
      result
    rescue Riffer::Messages::InvalidInputError => e
      raise InvalidInputError, e.message
    end
  end
end
