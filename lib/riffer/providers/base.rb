# frozen_string_literal: true

# Base class for all LLM providers in the Riffer framework.
#
# Subclasses must implement +perform_generate_text+ and +perform_stream_text+.
class Riffer::Providers::Base
  include Riffer::Helpers::Dependencies
  include Riffer::Messages::Converter

  # Generates text using the provider.
  #
  # prompt:: String or nil - the user prompt (required when messages is not provided)
  # system:: String or nil - an optional system message
  # messages:: Array or nil - optional messages array
  # model:: String or nil - optional model string to override the configured model
  # options:: Hash - additional options passed to the model invocation
  #
  # Returns Riffer::Messages::Assistant - the generated assistant message.
  def generate_text(prompt: nil, system: nil, messages: nil, model: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_generate_text(normalized_messages, model: model, **options)
  end

  # Streams text from the provider.
  #
  # prompt:: String or nil - the user prompt (required when messages is not provided)
  # system:: String or nil - an optional system message
  # messages:: Array or nil - optional messages array
  # model:: String or nil - optional model string to override the configured model
  # options:: Hash - additional options passed to the model invocation
  #
  # Returns Enumerator - an enumerator yielding stream events.
  def stream_text(prompt: nil, system: nil, messages: nil, model: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_stream_text(normalized_messages, model: model, **options)
  end

  private

  def perform_generate_text(messages, model: nil, **options)
    raise NotImplementedError, "Subclasses must implement #perform_generate_text"
  end

  def perform_stream_text(messages, model: nil, **options)
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
