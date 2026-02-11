# frozen_string_literal: true
# rbs_inline: enabled

# Base class for all LLM providers in the Riffer framework.
#
# Subclasses must implement +perform_generate_text+ and +perform_stream_text+.
class Riffer::Providers::Base
  include Riffer::Helpers::Dependencies
  include Riffer::Messages::Converter

  # Generates text using the provider.
  #
  #: (?prompt: String?, ?system: String?, ?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?model: String?, **untyped) -> Riffer::Messages::Assistant
  def generate_text(prompt: nil, system: nil, messages: nil, model: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_generate_text(normalized_messages, model: model, **options)
  end

  # Streams text from the provider.
  #
  #: (?prompt: String?, ?system: String?, ?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?model: String?, **untyped) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream_text(prompt: nil, system: nil, messages: nil, model: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_stream_text(normalized_messages, model: model, **options)
  end

  private

  #: (Array[Riffer::Messages::Base], ?model: String?, **untyped) -> Riffer::Messages::Assistant
  def perform_generate_text(messages, model: nil, **options)
    raise NotImplementedError, "Subclasses must implement #perform_generate_text"
  end

  #: (Array[Riffer::Messages::Base], ?model: String?, **untyped) -> Enumerator[Riffer::StreamEvents::Base, void]
  def perform_stream_text(messages, model: nil, **options)
    raise NotImplementedError, "Subclasses must implement #perform_stream_text"
  end

  #: (prompt: String?, system: String?, messages: Array[Hash[Symbol | String, untyped] | Riffer::Messages::Base]?) -> void
  def validate_input!(prompt:, system:, messages:)
    if messages.nil?
      raise Riffer::ArgumentError, "prompt is required when messages is not provided" if prompt.nil?
    else
      raise Riffer::ArgumentError, "cannot provide both prompt and messages" unless prompt.nil?
      raise Riffer::ArgumentError, "cannot provide both system and messages" unless system.nil?
    end
  end

  #: (prompt: String?, system: String?, messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?) -> Array[Riffer::Messages::Base]
  def normalize_messages(prompt:, system:, messages:)
    if messages
      return messages.map { |msg| convert_to_message_object(msg) }
    end

    result = []
    result << Riffer::Messages::System.new(system) if system
    result << Riffer::Messages::User.new(prompt)
    result
  end

  #: (Array[Riffer::Messages::Base]) -> void
  def validate_normalized_messages!(messages)
    has_user = messages.any? { |msg| msg.is_a?(Riffer::Messages::User) }
    raise Riffer::ArgumentError, "messages must include at least one user message" unless has_user
  end
end
