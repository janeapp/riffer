# frozen_string_literal: true

module Riffer
  class Agent
    class << self
      def provider(provider_name = nil)
        if provider_name.nil?
          @provider
        else
          @provider = provider_name
        end
      end

      def model(model_name = nil)
        if model_name.nil?
          @model
        else
          @model = model_name
        end
      end

      def instructions(instructions_text = nil)
        if instructions_text.nil?
          @instructions
        else
          @instructions = instructions_text
        end
      end
    end

    attr_reader :messages

    def initialize
      @messages = []
      @provider_name = self.class.provider
      @model_name = self.class.model
      @instructions_text = self.class.instructions
    end

    def run(prompt)
      initialize_messages(prompt)

      loop do
        response = call_llm
        @messages << response

        break unless has_tool_calls?(response)

        execute_tool_calls(response)
      end

      extract_final_response
    end

    private

    def initialize_messages(prompt)
      @messages = []
      @messages << Riffer::Agents::Messages::System.new(@instructions_text) if @instructions_text
      @messages << Riffer::Agents::Messages::User.new(prompt)
    end

    def call_llm
      response = provider_instance.generate_text(messages: @messages, model: @model_name)
      normalize_response(response)
    end

    def provider_instance
      @provider_instance ||= build_provider_instance
    end

    def build_provider_instance
      case @provider_name
      when :openai
        api_key = ENV["OPENAI_API_KEY"]
        raise ArgumentError, "OPENAI_API_KEY environment variable is required" if api_key.nil? || api_key.empty?
        Riffer::Agents::Providers::OpenAI.new(api_key: api_key)
      when :test
        Riffer::Agents::Providers::Test.new
      else
        raise ArgumentError, "Unknown provider: #{@provider_name}"
      end
    end

    def has_tool_calls?(response)
      response.is_a?(Riffer::Agents::Messages::Assistant) && !response.tool_calls.empty?
    end

    def execute_tool_calls(response)
      response.tool_calls.each do |tool_call|
        tool_result = execute_tool_call(tool_call)
        @messages << Riffer::Agents::Messages::Tool.new(
          tool_result,
          tool_call_id: tool_call[:id],
          name: tool_call[:name]
        )
      end
    end

    def execute_tool_call(tool_call)
      # TODO: Implement actual tool execution
      # This method should find and execute the appropriate tool based on tool_call[:name]
      # and return the result as a string
      "Tool execution not implemented yet"
    end

    def extract_final_response
      last_assistant_message = @messages.reverse.find { |msg| msg.is_a?(Riffer::Agents::Messages::Assistant) }
      last_assistant_message&.content || ""
    end

    def normalize_response(response)
      return response if response.is_a?(Riffer::Agents::Messages::Base)

      if response.is_a?(Hash)
        case response[:role]
        when "assistant"
          Riffer::Agents::Messages::Assistant.new(response[:content], tool_calls: response[:tool_calls] || [])
        else
          raise ArgumentError, "Unexpected response role: #{response[:role]}"
        end
      else
        raise ArgumentError, "Unexpected response type: #{response.class}"
      end
    end
  end
end
