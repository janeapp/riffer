# frozen_string_literal: true

module Riffer::Agents::Providers
  class Base
    include Riffer::DependencyHelper

    def generate_text(prompt: nil, system: nil, messages: nil)
      validate_input!(prompt: prompt, system: system, messages: messages)
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
      perform_generate_text(normalized_messages)
    end

    def stream_text(prompt: nil, system: nil, messages: nil)
      validate_input!(prompt: prompt, system: system, messages: messages)
      normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
      perform_stream_text(normalized_messages)
    end

    private

    def perform_generate_text(messages)
      raise NotImplementedError, "Subclasses must implement #perform_generate_text"
    end

    def perform_stream_text(messages)
      raise NotImplementedError, "Subclasses must implement #perform_stream_text"
    end

    def validate_input!(prompt:, system:, messages:)
      if messages.nil?
        raise Riffer::Agents::InvalidInputError, "prompt is required when messages is not provided" if prompt.nil?
      else
        raise Riffer::Agents::InvalidInputError, "cannot provide both prompt and messages" unless prompt.nil?
        raise Riffer::Agents::InvalidInputError, "cannot provide both system and messages" unless system.nil?
        raise Riffer::Agents::InvalidInputError, "messages must include at least one user message" unless has_user_message?(messages)
      end
    end

    def normalize_messages(prompt:, system:, messages:)
      return messages if messages

      result = []
      result << Riffer::Agents::Messages::System.new(system).to_h if system
      result << Riffer::Agents::Messages::User.new(prompt).to_h
      result
    end

    def has_user_message?(messages)
      messages.any? do |msg|
        msg.is_a?(Hash) && msg[:role] == "user" || msg.is_a?(Riffer::Agents::Messages::User)
      end
    end
  end
end
