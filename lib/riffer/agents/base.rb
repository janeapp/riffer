# frozen_string_literal: true

module Riffer::Agents
  class Base
    class << self
      def model(model_string = nil)
        return @model if model_string.nil?

        raise ArgumentError, "model must be a String" unless model_string.is_a?(String)
        raise ArgumentError, "model cannot be empty" if model_string.strip.empty?

        @model = model_string
      end

      def instructions(instructions_text = nil)
        return @instructions if instructions_text.nil?

        raise ArgumentError, "instructions must be a String" unless instructions_text.is_a?(String)
        raise ArgumentError, "instructions cannot be empty" if instructions_text.strip.empty?

        @instructions = instructions_text
      end

      def guardrail(guardrail_class, action: :mutate)
        @guardrails ||= []
        @guardrails << {class: guardrail_class, action: action}
      end

      def guardrails
        @guardrails || []
      end
    end

    attr_reader :messages

    def initialize
      @messages = []
      @model_string = self.class.model
      @instructions_text = self.class.instructions
      @guardrail_instances = self.class.guardrails.map { |g| {instance: g[:class].new, action: g[:action]} }

      provider_name, model_name = @model_string.split("/", 2)

      raise ArgumentError, "Invalid model string: #{@model_string}" unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }

      @provider_name = provider_name
      @model_name = model_name
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
      @messages = [] # Reset messages for each generation call
      @messages << Riffer::Messages::System.new(@instructions_text) if @instructions_text

      processed_prompt = apply_input_guardrails(prompt)
      @messages << Riffer::Messages::User.new(processed_prompt)
    end

    def apply_input_guardrails(content)
      @guardrail_instances.reduce(content) do |current_content, guardrail_config|
        guardrail_config[:instance].process_input(current_content)
      end
    end

    def apply_output_guardrails(content)
      @guardrail_instances.reduce(content) do |current_content, guardrail_config|
        guardrail_config[:instance].process_output(current_content)
      end
    end

    def call_llm
      provider_instance.generate_text(messages: @messages, model: @model_name)
    end

    def provider_instance
      @provider_instance ||= Riffer::Providers::Base.find_provider(@provider_name).new
    end

    def has_tool_calls?(response)
      response.is_a?(Riffer::Messages::Assistant) && !response.tool_calls.empty?
    end

    def execute_tool_calls(response)
      response.tool_calls.each do |tool_call|
        tool_result = execute_tool_call(tool_call)
        @messages << Riffer::Messages::Tool.new(
          tool_result,
          tool_call_id: tool_call[:id],
          name: tool_call[:name]
        )
      end
    end

    def execute_tool_call(tool_call)
      "Tool execution not implemented yet"
    end

    def extract_final_response
      last_assistant_message = @messages.reverse.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
      content = last_assistant_message&.content || ""
      apply_output_guardrails(content)
    end
  end
end
