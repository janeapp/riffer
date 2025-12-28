# frozen_string_literal: true

module Riffer::Providers
  class Base
    include Riffer::Helpers::Dependencies
    include Riffer::Messages::Converter

    class << self
      def identifier(value = nil)
        return @identifier if value.nil?

        @identifier = value
      end

      def find_provider(identifier)
        ensure_providers_loaded
        subclasses.find { |provider_class| provider_class.identifier == identifier }
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
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
      validate_normalized_messages!(normalized_messages)
      perform_generate_text(normalized_messages, model: model)
    end

    def stream_text(prompt: nil, system: nil, messages: nil, model: nil)
      validate_input!(prompt: prompt, system: system, messages: messages)
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
        raise Riffer::ArgumentError, "prompt is required when messages is not provided" if prompt.nil?
      else
        raise Riffer::ArgumentError, "cannot provide both prompt and messages" unless prompt.nil?
        raise Riffer::ArgumentError, "cannot provide both system and messages" unless system.nil?
      end
    end

    def normalize_messages(prompt:, system:, messages:)
      if messages
        return messages.map { |msg| convert_to_message_object(msg) }
      end

      result = []
      result << Riffer::Messages::System.new(system) if system
      result << Riffer::Messages::User.new(prompt)
      result
    end

    def validate_normalized_messages!(messages)
      has_user = messages.any? { |msg| msg.is_a?(Riffer::Messages::User) }
      raise Riffer::ArgumentError, "messages must include at least one user message" unless has_user
    end
  end
end
