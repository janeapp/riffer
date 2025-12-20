# frozen_string_literal: true

module Riffer::Agents
  class Base
    class << self
      def model(model_string = nil)
        return @model if model_string.nil?
        @model = model_string
      end

      def instructions(instructions_text = nil)
        return @instructions if instructions_text.nil?

        raise ArgumentError, "instructions must be a String" unless instructions_text.is_a?(String)
        raise ArgumentError, "instructions cannot be empty" if instructions_text.strip.empty?

        @instructions = instructions_text
      end
    end

    attr_reader :messages

    def initialize
      @messages = []
      @model_string = self.class.model
      @instructions_text = self.class.instructions
    end

    def generate(prompt)
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
      @model_name ||= @model_string.split("/", 2).last
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
