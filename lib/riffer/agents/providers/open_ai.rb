# frozen_string_literal: true

module Riffer
  module Agents
    module Providers
      # OpenAI provider for chat completions using the OpenAI API
      class OpenAI < Base
        def initialize(api_key:, **openai_options)
          super()
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

          extract_response_content(response)
        end

        def perform_stream_text(messages, model:)
          Enumerator.new do |yielder|
            params = build_request_params(messages, model)
            stream = @client.responses.stream(params)

            process_stream_events(stream, yielder)
          end
        end

        def build_request_params(messages, model)
          instructions = extract_instructions(messages)
          input = extract_input(messages)

          params = {model: model, input: input}
          params[:instructions] = instructions if instructions

          params
        end

        def extract_instructions(messages)
          system_messages = messages.select { |msg| msg[:role] == "system" }
          return nil if system_messages.empty?

          system_messages.map { |msg| msg[:content] }.join("\n")
        end

        def extract_input(messages)
          messages.reject { |msg| msg[:role] == "system" }
        end

        def extract_response_content(response)
          output_item = find_message_output(response)
          return default_response unless output_item

          content_item = output_item.content&.first
          return default_response unless content_item

          build_content_response(content_item)
        end

        def find_message_output(response)
          response.output&.find { |item| item.type == "message" }
        end

        def default_response
          {role: "assistant", content: nil}
        end

        def build_content_response(content_item)
          result = {role: "assistant"}

          case content_item.type
          when "output_text"
            result[:content] = content_item.text
          when "refusal"
            result[:content] = content_item.refusal
          end

          result.compact
        end

        def process_stream_events(stream, yielder)
          stream.each do |event|
            next unless should_process_event?(event)

            content = extract_event_content(event)
            yielder << content if content
          end
        end

        def should_process_event?(event)
          ["response.output_text.delta", "response.output_text.done"].include?(event.type)
        end

        def extract_event_content(event)
          case event.type
          when "response.output_text.delta"
            Riffer::Agents::StreamEvents::TextDelta.new(event.text)
          when "response.output_text.done"
            Riffer::Agents::StreamEvents::TextDone.new(event.text)
          end
        end
      end
    end
  end
end
