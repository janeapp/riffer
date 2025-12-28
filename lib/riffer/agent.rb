# frozen_string_literal: true

# Riffer::Agent is the base class for all agents in the Riffer framework.
# Provides orchestration for LLM calls, tool use, and message management.
#
# @abstract
# @see Riffer::Messages
# @see Riffer::Providers

class Riffer::Agent
  include Riffer::Messages::Converter
  include Riffer::Messages::Converter

  class << self
    include Riffer::Helpers::Validations

    # Gets or sets the agent identifier
    # @param value [String, nil]
    # @return [String]
    def identifier(value = nil)
      return @identifier if value.nil?
      @identifier = value.to_s
    end

    # Gets or sets the model string (e.g., "openai/gpt-4")
    # @param model_string [String, nil]
    # @return [String]
    def model(model_string = nil)
      return @model if model_string.nil?
      validate_is_string!(model_string, "model")
      @model = model_string
    end

    # Gets or sets the agent instructions
    # @param instructions_text [String, nil]
    # @return [String]
    def instructions(instructions_text = nil)
      return @instructions if instructions_text.nil?
      validate_is_string!(instructions_text, "instructions")
      @instructions = instructions_text
    end

    # Finds an agent class by identifier
    # @param identifier [String]
    # @return [Class, nil]
    def find(identifier)
      subclasses.find { |agent_class| agent_class.identifier == identifier.to_s }
    end

    # Returns all agent subclasses
    # @return [Array<Class>]
    def all
      subclasses
    end
  end

  # The message history for the agent
  # @return [Array<Riffer::Messages::Base>]
  attr_reader :messages

  # Initializes a new agent
  def initialize
    @messages = []
    @model_string = self.class.model
    @instructions_text = self.class.instructions

    provider_name, model_name = @model_string.split("/", 2)

    raise Riffer::ArgumentError, "Invalid model string: #{@model_string}" unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }

    @provider_name = provider_name
    @model_name = model_name
  end

  # Generates a response from the agent
  # @param prompt_or_messages [String, Array<Hash, Riffer::Messages::Base>]
  # @return [String]
  def generate(prompt_or_messages)
    initialize_messages(prompt_or_messages)

    loop do
      response = call_llm
      @messages << response

      break unless has_tool_calls?(response)

      execute_tool_calls(response)
    end

    extract_final_response
  end

  private

  # Initializes the message history
  # @param prompt_or_messages [String, Array<Hash, Riffer::Messages::Base>]
  # @return [void]
  def initialize_messages(prompt_or_messages)
    @messages = []
    @messages << Riffer::Messages::System.new(@instructions_text) if @instructions_text

    if prompt_or_messages.is_a?(Array)
      prompt_or_messages.each do |item|
        @messages << convert_to_message_object(item)
      end
    else
      @messages << Riffer::Messages::User.new(prompt_or_messages)
    end
  end

  # Calls the language model provider
  # @return [Riffer::Messages::Assistant]
  def call_llm
    provider_instance.generate_text(messages: @messages, model: @model_name)
  end

  # Returns the provider instance
  # @return [Riffer::Providers::Base]
  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Base.find_provider(@provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless provider_class
      provider_class.new
    end
  end

  # Checks if the response contains tool calls
  # @param response [Riffer::Messages::Assistant]
  # @return [Boolean]
  def has_tool_calls?(response)
    response.is_a?(Riffer::Messages::Assistant) && !response.tool_calls.empty?
  end

  # Executes all tool calls in the response
  # @param response [Riffer::Messages::Assistant]
  # @return [void]
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

  # Executes a single tool call (stub)
  # @param tool_call [Hash]
  # @return [String]
  def execute_tool_call(tool_call)
    "Tool execution not implemented yet"
  end

  # Extracts the final assistant message content
  # @return [String]
  def extract_final_response
    last_assistant_message = @messages.reverse.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
    last_assistant_message&.content || ""
  end
end
