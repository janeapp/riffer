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
  #: prompt: String? -- the user prompt (required when messages is not provided)
  #: system: String? -- an optional system message
  #: messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]? -- optional messages array
  #: model: String? -- optional model string to override the configured model
  #: **options: untyped
  #: return: Riffer::Messages::Assistant
  def generate_text(prompt: nil, system: nil, messages: nil, model: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_generate_text(normalized_messages, model: model, **options)
  end

  # Streams text from the provider.
  #
  #: prompt: String? -- the user prompt (required when messages is not provided)
  #: system: String? -- an optional system message
  #: messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]? -- optional messages array
  #: model: String? -- optional model string to override the configured model
  #: **options: untyped
  #: return: Enumerator[Riffer::StreamEvents::Base, void]
  def stream_text(prompt: nil, system: nil, messages: nil, model: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    normalized_messages = normalize_messages(prompt: prompt, system: system, messages: messages)
    validate_normalized_messages!(normalized_messages)
    perform_stream_text(normalized_messages, model: model, **options)
  end

  private

  #: messages: Array[Riffer::Messages::Base]
  #: model: String?
  #: **options: untyped
  #: return: Riffer::Messages::Assistant
  def perform_generate_text(messages, model: nil, **options)
    raise NotImplementedError, "Subclasses must implement #perform_generate_text"
  end

  #: messages: Array[Riffer::Messages::Base]
  #: model: String?
  #: **options: untyped
  #: return: Enumerator[Riffer::StreamEvents::Base, void]
  def perform_stream_text(messages, model: nil, **options)
    raise NotImplementedError, "Subclasses must implement #perform_stream_text"
  end

  #: prompt: String?
  #: system: String?
  #: messages: Array[Hash[Symbol | String, untyped] | Riffer::Messages::Base]?
  #: return: void
  def validate_input!(prompt:, system:, messages:)
    if messages.nil?
      raise Riffer::ArgumentError, "prompt is required when messages is not provided" if prompt.nil?
    else
      raise Riffer::ArgumentError, "cannot provide both prompt and messages" unless prompt.nil?
      raise Riffer::ArgumentError, "cannot provide both system and messages" unless system.nil?
    end
  end

  #: prompt: String?
  #: system: String?
  #: messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?
  #: return: Array[Riffer::Messages::Base]
  def normalize_messages(prompt:, system:, messages:)
    if messages
      return messages.map { |msg| convert_to_message_object(msg) }
    end

    result = []
    result << Riffer::Messages::System.new(system) if system
    result << Riffer::Messages::User.new(prompt)
    result
  end

  #: messages: Array[Riffer::Messages::Base]
  #: return: void
  def validate_normalized_messages!(messages)
    has_user = messages.any? { |msg| msg.is_a?(Riffer::Messages::User) }
    raise Riffer::ArgumentError, "messages must include at least one user message" unless has_user
  end
end
