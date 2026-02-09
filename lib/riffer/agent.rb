# frozen_string_literal: true
# rbs_inline: enabled

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
  extend Riffer::Helpers::ClassNameConverter
  extend Riffer::Helpers::Validations

  #: self.@identifier: String?
  #: self.@model: String?
  #: self.@instructions: String?
  #: self.@provider_options: Hash[Symbol, untyped]?
  #: self.@model_options: Hash[Symbol, untyped]?
  #: self.@tools_config: (Array[singleton(Riffer::Tool)] | Proc)?

  #: @messages: Array[Riffer::Messages::Base]
  #: @message_callbacks: Array[^(Riffer::Messages::Base) -> void]
  #: @token_usage: Riffer::TokenUsage?
  #: @model_string: String
  #: @instructions_text: String?
  #: @provider_name: String
  #: @model_name: String
  #: @tool_context: Hash[Symbol, untyped]?
  #: @resolved_tools: Array[singleton(Riffer::Tool)]?
  #: @provider_instance: Riffer::Providers::Base?

  # Gets or sets the agent identifier.
  #
  #: value: String? -- the identifier to set, or nil to get
  #: return: String
  def self.identifier(value = nil)
    return @identifier || class_name_to_path(name) if value.nil?
    @identifier = value.to_s
  end

  # Gets or sets the model string (e.g., "openai/gpt-4o").
  #
  #: model_string: String? -- the model string to set, or nil to get
  #: return: String?
  def self.model(model_string = nil)
    return @model if model_string.nil?
    validate_is_string!(model_string, "model")
    @model = model_string
  end

  # Gets or sets the agent instructions.
  #
  #: instructions_text: String? -- the instructions to set, or nil to get
  #: return: String?
  def self.instructions(instructions_text = nil)
    return @instructions if instructions_text.nil?
    validate_is_string!(instructions_text, "instructions")
    @instructions = instructions_text
  end

  # Gets or sets provider options passed to the provider client.
  #
  #: options: Hash[Symbol, untyped]? -- the options to set, or nil to get
  #: return: Hash[Symbol, untyped]
  def self.provider_options(options = nil)
    return @provider_options || {} if options.nil?
    @provider_options = options
  end

  # Gets or sets model options passed to generate_text/stream_text.
  #
  #: options: Hash[Symbol, untyped]? -- the options to set, or nil to get
  #: return: Hash[Symbol, untyped]
  def self.model_options(options = nil)
    return @model_options || {} if options.nil?
    @model_options = options
  end

  # Gets or sets the tools used by this agent.
  #
  #: tools_or_lambda: (Array[singleton(Riffer::Tool)] | Proc)? -- tools array or lambda returning tools
  #: return: (Array[singleton(Riffer::Tool)] | Proc)?
  def self.uses_tools(tools_or_lambda = nil)
    return @tools_config if tools_or_lambda.nil?
    @tools_config = tools_or_lambda
  end

  # Finds an agent class by identifier.
  #
  #: identifier: String -- the identifier to search for
  #: return: singleton(Riffer::Agent)?
  def self.find(identifier)
    subclasses.find { |agent_class| agent_class.identifier == identifier.to_s }
  end

  # Returns all agent subclasses.
  #
  #: return: Array[singleton(Riffer::Agent)]
  def self.all
    subclasses
  end

  # Generates a response using a new agent instance.
  #
  # See #generate for parameters and return value.
  #
  #: *args: untyped
  #: **kwargs: untyped
  #: return: String
  def self.generate(...)
    new.generate(...)
  end

  # Streams a response using a new agent instance.
  #
  # See #stream for parameters and return value.
  #
  #: *args: untyped
  #: **kwargs: untyped
  #: return: Enumerator[Riffer::StreamEvents::Base, void]
  def self.stream(...)
    new.stream(...)
  end

  # The message history for the agent.
  attr_reader :messages #: Array[Riffer::Messages::Base]

  # Cumulative token usage across all LLM calls.
  attr_reader :token_usage #: Riffer::TokenUsage?

  # Initializes a new agent.
  #
  # Raises Riffer::ArgumentError if the configured model string is invalid
  # (must be "provider/model" format).
  #
  #: return: void
  def initialize
    @messages = []
    @message_callbacks = []
    @token_usage = nil
    @model_string = self.class.model
    @instructions_text = self.class.instructions

    provider_name, model_name = @model_string.split("/", 2)

    raise Riffer::ArgumentError, "Invalid model string: #{@model_string}" unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }

    @provider_name = provider_name
    @model_name = model_name
  end

  # Generates a response from the agent.
  #
  #: prompt_or_messages: (String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base])
  #: tool_context: Hash[Symbol, untyped]? -- optional context object passed to all tool calls
  #: return: String
  def generate(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    @resolved_tools = nil
    initialize_messages(prompt_or_messages)

    loop do
      response = call_llm
      add_message(response)
      track_token_usage(response.token_usage)

      break unless has_tool_calls?(response)

      execute_tool_calls(response)
    end

    extract_final_response
  end

  # Streams a response from the agent.
  #
  #: prompt_or_messages: (String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base])
  #: tool_context: Hash[Symbol, untyped]? -- optional context object passed to all tool calls
  #: return: Enumerator[Riffer::StreamEvents::Base, void]
  def stream(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    @resolved_tools = nil
    initialize_messages(prompt_or_messages)

    Enumerator.new do |yielder|
      loop do
        accumulated_content = ""
        accumulated_tool_calls = []
        accumulated_token_usage = nil
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
            accumulated_tool_calls << Riffer::Messages::Assistant::ToolCall.new(
              id: event.item_id,
              call_id: event.call_id,
              name: event.name,
              arguments: event.arguments
            )
            current_tool_call = nil
          when Riffer::StreamEvents::TokenUsageDone
            accumulated_token_usage = event.token_usage
          end
        end

        response = Riffer::Messages::Assistant.new(
          accumulated_content,
          tool_calls: accumulated_tool_calls,
          token_usage: accumulated_token_usage
        )
        add_message(response)
        track_token_usage(accumulated_token_usage)

        break unless has_tool_calls?(response)

        execute_tool_calls(response)
      end
    end
  end

  # Registers a callback to be invoked when messages are added during generation.
  #
  # Raises Riffer::ArgumentError if no block is given.
  #
  #: &block: (Riffer::Messages::Base) -> void
  #: return: self
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?
    @message_callbacks << block
    self
  end

  private

  #: message: Riffer::Messages::Base
  #: return: void
  def add_message(message)
    @messages << message
    @message_callbacks.each { |callback| callback.call(message) }
  end

  #: usage: Riffer::TokenUsage?
  #: return: void
  def track_token_usage(usage)
    return unless usage

    @token_usage = @token_usage ? @token_usage + usage : usage
  end

  #: prompt_or_messages: (String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base])
  #: return: void
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

  #: return: Riffer::Messages::Assistant
  def call_llm
    provider_instance.generate_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
      **self.class.model_options
    )
  end

  #: return: Enumerator[Riffer::StreamEvents::Base, void]
  def call_llm_stream
    provider_instance.stream_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
      **self.class.model_options
    )
  end

  #: return: Riffer::Providers::Base
  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Repository.find(@provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless provider_class
      provider_class.new(**self.class.provider_options)
    end
  end

  #: response: Riffer::Messages::Assistant
  #: return: bool
  def has_tool_calls?(response)
    response.is_a?(Riffer::Messages::Assistant) && !response.tool_calls.empty?
  end

  #: response: Riffer::Messages::Assistant
  #: return: void
  def execute_tool_calls(response)
    response.tool_calls.each do |tool_call|
      result = execute_tool_call(tool_call)
      add_message(Riffer::Messages::Tool.new(
        result.content,
        tool_call_id: tool_call.id,
        name: tool_call.name,
        error: result.error_message,
        error_type: result.error_type
      ))
    end
  end

  #: tool_call: Riffer::Messages::Assistant::ToolCall
  #: return: Riffer::Tools::Response
  def execute_tool_call(tool_call)
    tool_class = find_tool_class(tool_call.name)

    if tool_class.nil?
      return Riffer::Tools::Response.error(
        "Unknown tool '#{tool_call.name}'",
        type: :unknown_tool
      )
    end

    tool_instance = tool_class.new
    arguments = parse_tool_arguments(tool_call.arguments)

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

  #: return: Array[singleton(Riffer::Tool)]
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

  #: name: String
  #: return: singleton(Riffer::Tool)?
  def find_tool_class(name)
    resolved_tools.find { |tool_class| tool_class.name == name }
  end

  #: arguments: (String | Hash[String, untyped])?
  #: return: Hash[Symbol, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    args = arguments.is_a?(String) ? JSON.parse(arguments) : arguments
    args.transform_keys(&:to_sym)
  end

  #: return: String
  def extract_final_response
    last_assistant_message = @messages.reverse.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
    last_assistant_message&.content || ""
  end
end
