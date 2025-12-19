# frozen_string_literal: true

require "openai"

module Riffer::Agents::Providers
  # OpenAI provider for chat completions using the OpenAI API
  class OpenAI < Base
    def initialize(api_key:, **openai_options)
      depends_on "openai"

      raise ArgumentError, "api_key is required" if api_key.nil? || api_key.empty?

      @client = ::OpenAI::Client.new(
        api_key: api_key,
        **openai_options
      )
    end

    private

    def perform_generate_text(messages, model:)
      params = build_request_params(messages, model)
      response = @client.responses.create(params)

      output = response.output.find { |o| o.type == :message }

      if output.nil?
        raise Riffer::Agents::Providers::Error, "No output returned from OpenAI API"
      end

      content = output.content.find { |c| c.type == :output_text }

      if content.nil?
        raise Riffer::Agents::Providers::Error, "No content returned from OpenAI API"
      end

      if content.type == :refusal
        raise Riffer::Agents::Providers::Error, "Request was refused: #{content.refusal}"
      end

      if content.type != :output_text
        raise Riffer::Agents::Providers::Error, "Unexpected content type: #{content.type}"
      end

      Riffer::Agents::Messages::Assistant.new(content.text)
    end

    def perform_stream_text(messages, model:)
      Enumerator.new do |yielder|
        params = build_request_params(messages, model)
        stream = @client.responses.stream(params)

        process_stream_events(stream, yielder)
      end
    end

    def build_request_params(messages, model)
      {
        model: model,
        input: convert_message_to_openai_format(messages)
      }
    end

    def convert_message_to_openai_format(messages)
      messages.map do |message|
        case message
        when Riffer::Agents::Messages::System
          {role: "developer", content: message.content}
        when Riffer::Agents::Messages::User
          {role: "user", content: message.content}
        when Riffer::Agents::Messages::Assistant
          {role: "assistant", content: message.content}
        when Riffer::Agents::Messages::Tool
          raise Riffer::Agents::Providers::InvalidInputError, "Tool messages are not supported by OpenAI provider yet"
        when Hash
          message
        else
          raise Riffer::Agents::Providers::InvalidInputError, "Unsupported message type: #{message.class}"
        end
      end
    end

    def process_stream_events(stream, yielder)
      stream.each do |event|
        next unless should_process_event?(event)

        content = extract_event_content(event)
        yielder << content if content
      end
    end

    def should_process_event?(event)
      [:"response.output_text.delta", :"response.output_text.done"].include?(event.type)
    end

    def extract_event_content(event)
      case event.type
      when :"response.output_text.delta"
        Riffer::Agents::StreamEvents::TextDelta.new(event.delta)
      when :"response.output_text.done"
        Riffer::Agents::StreamEvents::TextDone.new(event.text)
      end
    end
  end
end
