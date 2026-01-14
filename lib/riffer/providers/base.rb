# frozen_string_literal: true

class Riffer::Providers::Base
  include Riffer::Helpers::Dependencies
  include Riffer::Messages::Converter

  # Generates text using the provider.
  #
  # @param prompt [String, nil] the user prompt (required when `messages` is not provided)
  # @param system [String, nil] an optional system message
  # @param messages [Array<Hash, Riffer::Messages::Base>, nil] optional messages array
  # @param model [String, nil] optional model string to override the configured model
  # @param reasoning [String, nil] optional reasoning level or instructions
  # @return [Riffer::Messages::Assistant] the generated assistant message
  def generate_text(prompt: nil, system: nil, messages: nil, model: nil, reasoning: nil)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_generate_text(normalized_messages, model: model, reasoning: reasoning)
  end

  # Streams text from the provider.
  #
  # @param prompt [String, nil] the user prompt (required when `messages` is not provided)
  # @param system [String, nil] an optional system message
  # @param messages [Array<Hash, Riffer::Messages::Base>, nil] optional messages array
  # @param model [String, nil] optional model string to override the configured model
  # @param reasoning [String, nil] optional reasoning level or instructions
  # @return [Enumerator] an enumerator yielding stream events or chunks (provider-specific)
  def stream_text(prompt: nil, system: nil, messages: nil, model: nil, reasoning: nil)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_stream_text(normalized_messages, model: model, reasoning: reasoning)
  end

  private

  def perform_generate_text(messages, model: nil, reasoning: nil)
    raise NotImplementedError, "Subclasses must implement #perform_generate_text"
  end

  def perform_stream_text(messages, model: nil, reasoning: nil)
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
