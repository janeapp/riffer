# frozen_string_literal: true

require "json"

# Riffer::Agent is the base class for all agents in the Riffer framework.
#
# Provides orchestration for LLM calls, tool use, and message management.
#
# @abstract
# @see Riffer::Messages
# @see Riffer::Providers
class Riffer::Agent
  include Riffer::Messages::Converter

  class << self
    include Riffer::Helpers::ClassNameConverter
    include Riffer::Helpers::Validations

    # Gets or sets the agent identifier
    # @param value [String, nil] the identifier to set, or nil to get
    # @return [String] the agent identifier
    def identifier(value = nil)
      return @identifier || class_name_to_path(name) if value.nil?
      @identifier = value.to_s
    end

    # Gets or sets the model string (e.g., "openai/gpt-4")
    # @param model_string [String, nil] the model string to set, or nil to get
    # @return [String] the model string
    def model(model_string = nil)
      return @model if model_string.nil?
      validate_is_string!(model_string, "model")
      @model = model_string
    end

    # Gets or sets the agent instructions
    # @param instructions_text [String, nil] the instructions to set, or nil to get
    # @return [String] the agent instructions
    def instructions(instructions_text = nil)
      return @instructions if instructions_text.nil?
      validate_is_string!(instructions_text, "instructions")
      @instructions = instructions_text
    end

    # Gets or sets provider options passed to the provider client
    # @param options [Hash, nil] the options to set, or nil to get
    # @return [Hash] the provider options
    def provider_options(options = nil)
      return @provider_options || {} if options.nil?
      @provider_options = options
    end

    # Gets or sets model options passed to generate_text/stream_text
    # @param options [Hash, nil] the options to set, or nil to get
    # @return [Hash] the model options
    def model_options(options = nil)
      return @model_options || {} if options.nil?
      @model_options = options
    end

    # Gets or sets the tools used by this agent
    # @param tools_or_lambda [Array<Class>, Proc, nil] tools array or lambda returning tools
    # @return [Array<Class>, Proc, nil] the tools configuration
    def uses_tools(tools_or_lambda = nil)
      return @tools_config if tools_or_lambda.nil?
      @tools_config = tools_or_lambda
    end

    # Finds an agent class by identifier
    # @param identifier [String] the identifier to search for
    # @return [Class, nil] the agent class, or nil if not found
    def find(identifier)
      subclasses.find { |agent_class| agent_class.identifier == identifier.to_s }
    end

    # Returns all agent subclasses
    # @return [Array<Class>] all agent subclasses
    def all
      subclasses
    end
  end

  # The message history for the agent
  # @return [Array<Riffer::Messages::Base>]
  attr_reader :messages

  # Initializes a new agent
  # @raise [Riffer::ArgumentError] if the configured model string is invalid (must be "provider/model")
  # @return [void]
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
  # @param tool_context [Object, nil] optional context object passed to all tool calls
  # @return [String]
  def generate(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    initialize_messages(prompt_or_messages)

    loop do
      response = call_llm
      @messages << response

      break unless has_tool_calls?(response)

      execute_tool_calls(response)
    end

    extract_final_response
  end

  # Streams a response from the agent
  # @param prompt_or_messages [String, Array<Hash, Riffer::Messages::Base>]
  # @param tool_context [Object, nil] optional context object passed to all tool calls
  # @return [Enumerator] an enumerator yielding stream events
  def stream(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    initialize_messages(prompt_or_messages)

    Enumerator.new do |yielder|
      loop do
        accumulated_content = ""
        accumulated_tool_calls = []
        current_tool_call = nil

        call_llm_stream.each do |event|
          yielder << event

          case event
          when Riffer::StreamEvents::TextDelta
            accumulated_content += event.content
          when Riffer::StreamEvents::TextDone
            accumulated_content = event.content
          when Riffer::StreamEvents::ToolCallDelta
            current_tool_call ||= {item_id: event.item_id, name: event.name, arguments: ""}
            current_tool_call[:arguments] += event.arguments_delta
            current_tool_call[:name] ||= event.name
          when Riffer::StreamEvents::ToolCallDone
            accumulated_tool_calls << {
              id: event.item_id,
              call_id: event.call_id,
              name: event.name,
              arguments: event.arguments
            }
            current_tool_call = nil
          end
        end

        response = Riffer::Messages::Assistant.new(accumulated_content, tool_calls: accumulated_tool_calls)
        @messages << response

        break unless has_tool_calls?(response)

        execute_tool_calls(response)
      end
    end
  end

  private

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

  def call_llm
    provider_instance.generate_text(
      messages: @messages,
      model: @model_name,
      tools: tool_definitions,
      **self.class.model_options
    )
  end

  def call_llm_stream
    provider_instance.stream_text(
      messages: @messages,
      model: @model_name,
      tools: tool_definitions,
      **self.class.model_options
    )
  end

  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Repository.find(@provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless provider_class
      provider_class.new(**self.class.provider_options)
    end
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
    tool_class = find_tool_class(tool_call[:name])

    if tool_class.nil?
      return "Error: Unknown tool '#{tool_call[:name]}'"
    end

    tool_instance = tool_class.new
    arguments = parse_tool_arguments(tool_call[:arguments])

    begin
      result = tool_instance.call_with_validation(context: @tool_context, **arguments)
      result.to_s
    rescue Riffer::ValidationError => e
      "Validation error: #{e.message}"
    rescue => e
      "Error executing tool: #{e.message}"
    end
  end

  def resolved_tools
    @resolved_tools ||= begin
      config = self.class.uses_tools
      return [] if config.nil?

      config.is_a?(Proc) ? config.call : config
    end
  end

  def tool_definitions
    resolved_tools
  end

  def find_tool_class(name)
    resolved_tools.find { |tool_class| tool_class.name == name }
  end

  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    args = arguments.is_a?(String) ? JSON.parse(arguments) : arguments
    args.transform_keys(&:to_sym)
  end

  def extract_final_response
    last_assistant_message = @messages.reverse.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
    last_assistant_message&.content || ""
  end
end
