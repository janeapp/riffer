# frozen_string_literal: true

module Riffer::Providers
  class Base
    include Riffer::DependencyHelper

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
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
      perform_generate_text(normalized_messages, model: model)
    end

    def stream_text(prompt: nil, system: nil, messages: nil, model: nil)
      validate_input!(prompt: prompt, system: system, messages: messages)
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
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
        raise InvalidInputError, "messages must include at least one user message" unless has_user_message?(messages)
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

    def convert_to_message_object(msg)
      if msg.is_a?(Riffer::Messages::Base)
        return msg
      end

      unless msg.is_a?(Hash)
        raise InvalidInputError, "Message must be a Hash or Message object, got #{msg.class}"
      end

      case msg[:role]
      when "user"
        Riffer::Messages::User.new(msg[:content])
      when "assistant"
        Riffer::Messages::Assistant.new(msg[:content], tool_calls: msg[:tool_calls] || [])
      when "system"
        Riffer::Messages::System.new(msg[:content])
      when "tool"
        Riffer::Messages::Tool.new(msg[:content], tool_call_id: msg[:tool_call_id], name: msg[:name])
      else
        raise InvalidInputError, "Unknown message role: #{msg[:role]}"
      end
    end

    def has_user_message?(messages)
      messages.any? do |msg|
        msg.is_a?(Riffer::Messages::User) || (msg.is_a?(Hash) && msg[:role] == "user")
      end
    end
  end
end
