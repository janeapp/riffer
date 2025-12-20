# frozen_string_literal: true

module Riffer
  class Agent
    class << self
      def model(model_string = nil)
        if model_string.nil?
          @model
        else
          @model = model_string
        end
      end

      def instructions(instructions_text = nil)
        if instructions_text.nil?
          @instructions
        else
          raise ArgumentError, "instructions must be a String" unless instructions_text.is_a?(String)
          @instructions = instructions_text
        end
      end
    end

    attr_reader :messages

    def initialize
      @messages = []
      @model_string = self.class.model
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
      provider_instance.generate_text(messages: @messages, model: model_name)
    end

    def provider_instance
      @provider_instance ||= build_provider_instance
    end

    def build_provider_instance
      Riffer::Agents::Providers::Factory.build(@model_string)
    end

    def model_name
      return nil unless @model_string

      parts = @model_string.split("/", 2)
      raise ArgumentError, "Model string must be in format 'provider/model'" if parts.size != 2

      model = parts[1]
      raise ArgumentError, "Model name must be a non-empty string" if model.nil? || model.empty? || !model.is_a?(String)

      model
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
  end
end
