# frozen_string_literal: true

require "json"

# Riffer::Agent is the base class for all agents in the Riffer framework.
#
# Provides orchestration for LLM calls, tool use, and message management.
# Subclass this to create your own agents.
#
# See Riffer::Messages and Riffer::Providers.
#
#   class MyAgent < Riffer::Agent
#     model 'openai/gpt-4o'
#     instructions 'You are a helpful assistant.'
#   end
#
#   agent = MyAgent.new
#   agent.generate('Hello!')
#
class Riffer::Agent
  include Riffer::Messages::Converter

  class << self
    include Riffer::Helpers::ClassNameConverter
    include Riffer::Helpers::Validations

    # Gets or sets the agent identifier.
    #
    # value:: String or nil - the identifier to set, or nil to get
    #
    # Returns String - the agent identifier.
    def identifier(value = nil)
      return @identifier || class_name_to_path(name) if value.nil?
      @identifier = value.to_s
    end

    # Gets or sets the model string (e.g., "openai/gpt-4o").
    #
    # model_string:: String or nil - the model string to set, or nil to get
    #
    # Returns String - the model string.
    def model(model_string = nil)
      return @model if model_string.nil?
      validate_is_string!(model_string, "model")
      @model = model_string
    end

    # Gets or sets the agent instructions.
    #
    # instructions_text:: String or nil - the instructions to set, or nil to get
    #
    # Returns String - the agent instructions.
    def instructions(instructions_text = nil)
      return @instructions if instructions_text.nil?
      validate_is_string!(instructions_text, "instructions")
      @instructions = instructions_text
    end

    # Gets or sets provider options passed to the provider client.
    #
    # options:: Hash or nil - the options to set, or nil to get
    #
    # Returns Hash - the provider options.
    def provider_options(options = nil)
      return @provider_options || {} if options.nil?
      @provider_options = options
    end

    # Gets or sets model options passed to generate_text/stream_text.
    #
    # options:: Hash or nil - the options to set, or nil to get
    #
    # Returns Hash - the model options.
    def model_options(options = nil)
      return @model_options || {} if options.nil?
      @model_options = options
    end

    # Gets or sets the tools used by this agent.
    #
    # tools_or_lambda:: Array of Tool classes, Proc, or nil - tools array or lambda returning tools
    #
    # Returns Array, Proc, or nil - the tools configuration.
    def uses_tools(tools_or_lambda = nil)
      return @tools_config if tools_or_lambda.nil?
      @tools_config = tools_or_lambda
    end

    # Finds an agent class by identifier.
    #
    # identifier:: String - the identifier to search for
    #
    # Returns Class or nil - the agent class, or nil if not found.
    def find(identifier)
      subclasses.find { |agent_class| agent_class.identifier == identifier.to_s }
    end

    # Returns all agent subclasses.
    #
    # Returns Array of Class - all agent subclasses.
    def all
      subclasses
    end
  end

  # The message history for the agent.
  #
  # Returns Array of Riffer::Messages::Base.
  attr_reader :messages

  # Initializes a new agent.
  #
  # Raises Riffer::ArgumentError if the configured model string is invalid
  # (must be "provider/model" format).
  def initialize
    @messages = []
    @message_callbacks = []
    @model_string = self.class.model
    @instructions_text = self.class.instructions

    provider_name, model_name = @model_string.split("/", 2)

    raise Riffer::ArgumentError, "Invalid model string: #{@model_string}" unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }

    @provider_name = provider_name
    @model_name = model_name
  end

  # Generates a response from the agent.
  #
  # prompt_or_messages:: String or Array - a string prompt or array of message hashes/objects
  # tool_context:: Object or nil - optional context object passed to all tool calls
  #
  # Returns String - the final response content.
  def generate(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    @resolved_tools = nil
    initialize_messages(prompt_or_messages)

    loop do
      response = call_llm
      add_message(response)

      break unless has_tool_calls?(response)

      execute_tool_calls(response)
    end

    extract_final_response
  end

  # Streams a response from the agent.
  #
  # prompt_or_messages:: String or Array - a string prompt or array of message hashes/objects
  # tool_context:: Object or nil - optional context object passed to all tool calls
  #
  # Returns Enumerator - an enumerator yielding stream events.
  def stream(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    @resolved_tools = nil
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
        add_message(response)

        break unless has_tool_calls?(response)

        execute_tool_calls(response)
      end
    end
  end

  # Registers a callback to be invoked when messages are added during generation.
  #
  # block:: Block - callback receiving a Riffer::Messages::Base subclass
  #
  # Raises Riffer::ArgumentError if no block is given.
  #
  # Returns self for method chaining.
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?
    @message_callbacks << block
    self
  end

  private

  def add_message(message)
    @messages << message
    @message_callbacks.each { |callback| callback.call(message) }
  end

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
      tools: resolved_tools,
      **self.class.model_options
    )
  end

  def call_llm_stream
    provider_instance.stream_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
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
      result = execute_tool_call(tool_call)
      add_message(Riffer::Messages::Tool.new(
        result.content,
        tool_call_id: tool_call[:id],
        name: tool_call[:name],
        error: result.error_message,
        error_type: result.error_type
      ))
    end
  end

  def execute_tool_call(tool_call)
    tool_class = find_tool_class(tool_call[:name])

    if tool_class.nil?
      return Riffer::Tools::Response.error(
        "Unknown tool '#{tool_call[:name]}'",
        type: :unknown_tool
      )
    end

    tool_instance = tool_class.new
    arguments = parse_tool_arguments(tool_call[:arguments])

    begin
      tool_instance.call_with_validation(context: @tool_context, **arguments)
    rescue Riffer::TimeoutError => e
      Riffer::Tools::Response.error(e.message, type: :timeout_error)
    rescue Riffer::ValidationError => e
      Riffer::Tools::Response.error(e.message, type: :validation_error)
    rescue => e
      Riffer::Tools::Response.error("Error executing tool: #{e.message}", type: :execution_error)
    end
  end

  def resolved_tools
    @resolved_tools ||= begin
      config = self.class.uses_tools
      return [] if config.nil?

      if config.is_a?(Proc)
        (config.arity == 0) ? config.call : config.call(@tool_context)
      else
        config
      end
    end
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
