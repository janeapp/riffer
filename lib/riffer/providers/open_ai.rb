# frozen_string_literal: true

class Riffer::Providers::OpenAI < Riffer::Providers::Base
  # Initializes the OpenAI provider.
  # @param options [Hash] optional client options. Use `:api_key` to override `Riffer.config.openai.api_key`.
  # @raise [Riffer::ArgumentError] if an API key is not provided either via `:api_key` or `Riffer.config.openai.api_key`.
  def initialize(**options)
    depends_on "openai"

    api_key = options.fetch(:api_key, Riffer.config.openai.api_key)
    raise Riffer::ArgumentError, "OpenAI API key is required. Set it via Riffer.configure or pass :api_key option" if api_key.nil? || api_key.empty?

    @client = ::OpenAI::Client.new(api_key: api_key, **options.except(:api_key))
  end

  private

  def perform_generate_text(messages, model:, reasoning: nil)
    params = build_request_params(messages, model, reasoning)
    response = @client.responses.create(params)

    output = response.output.find { |o| o.type == :message }

    if output.nil?
      raise Riffer::Error, "No output returned from OpenAI API"
    end

    content = output.content.find { |c| c.type == :output_text }

    if content.nil?
      raise Riffer::Error, "No content returned from OpenAI API"
    end

    if content.type == :refusal
      raise Riffer::Error, "Request was refused: #{content.refusal}"
    end

    if content.type != :output_text
      raise Riffer::Error, "Unexpected content type: #{content.type}"
    end

    Riffer::Messages::Assistant.new(content.text)
  end

  def perform_stream_text(messages, model:, reasoning: nil)
    Enumerator.new do |yielder|
      params = build_request_params(messages, model, reasoning)
      stream = @client.responses.stream(params)

      process_stream_events(stream, yielder)
    end
  end

  def build_request_params(messages, model, reasoning)
    {
      input: convert_message_to_openai_format(messages),
      model: model,
      reasoning: reasoning && {
        effort: reasoning,
        summary: "auto"
      }
    }
  end

  def convert_message_to_openai_format(messages)
    messages.map do |message|
      case message
      when Riffer::Messages::System
        {role: "developer", content: message.content}
      when Riffer::Messages::User
        {role: "user", content: message.content}
      when Riffer::Messages::Assistant
        {role: "assistant", content: message.content}
      when Riffer::Messages::Tool
        raise NotImplementedError, "Tool messages are not supported by OpenAI provider yet"
      end
    end
  end

  def process_stream_events(stream, yielder)
    stream.each do |raw_event|
      event = convert_event(raw_event)

      next unless event

      yielder << event if event
    end
  end

  def convert_event(event)
    case event.type
    when :"response.output_text.delta"
      Riffer::StreamEvents::TextDelta.new(event.delta)
    when :"response.output_text.done"
      Riffer::StreamEvents::TextDone.new(event.text)
    when :"response.reasoning_summary_text.delta"
      Riffer::StreamEvents::ReasoningDelta.new(event.delta)
    when :"response.reasoning_summary_text.done"
      Riffer::StreamEvents::ReasoningDone.new(event.text)
    end
  end
end
