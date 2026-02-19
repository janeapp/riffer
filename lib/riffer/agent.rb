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

  DEFAULT_MAX_STEPS = 16 #: Integer
  INTERRUPT_MAX_STEPS = :max_steps #: Symbol

  # Gets or sets the agent identifier.
  #
  #: (?String?) -> String
  def self.identifier(value = nil)
    return @identifier || class_name_to_path(name) if value.nil?
    @identifier = value.to_s
  end

  # Gets or sets the model string (e.g., "openai/gpt-4o").
  #
  #: (?String?) -> String?
  def self.model(model_string = nil)
    return @model if model_string.nil?
    validate_is_string!(model_string, "model")
    @model = model_string
  end

  # Gets or sets the agent instructions.
  #
  #: (?String?) -> String?
  def self.instructions(instructions_text = nil)
    return @instructions if instructions_text.nil?
    validate_is_string!(instructions_text, "instructions")
    @instructions = instructions_text
  end

  # Gets or sets provider options passed to the provider client.
  #
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.provider_options(options = nil)
    return @provider_options || {} if options.nil?
    @provider_options = options
  end

  # Gets or sets model options passed to generate_text/stream_text.
  #
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.model_options(options = nil)
    return @model_options || {} if options.nil?
    @model_options = options
  end

  # Gets or sets the maximum number of LLM call steps in the tool-use loop.
  #
  # Defaults to DEFAULT_MAX_STEPS (16). Set to +Float::INFINITY+ for
  # unlimited steps.
  #
  #: (?Numeric?) -> Numeric
  def self.max_steps(value = nil)
    return @max_steps || DEFAULT_MAX_STEPS if value.nil?
    @max_steps = value
  end

  # Gets or sets the tools used by this agent.
  #
  #: (?(Array[singleton(Riffer::Tool)] | Proc)?) -> (Array[singleton(Riffer::Tool)] | Proc)?
  def self.uses_tools(tools_or_lambda = nil)
    return @tools_config if tools_or_lambda.nil?
    @tools_config = tools_or_lambda
  end

  # Finds an agent class by identifier.
  #
  #: (String) -> singleton(Riffer::Agent)?
  def self.find(identifier)
    subclasses.find { |agent_class| agent_class.identifier == identifier.to_s }
  end

  # Returns all agent subclasses.
  #
  #: () -> Array[singleton(Riffer::Agent)]
  def self.all
    subclasses
  end

  # Generates a response using a new agent instance.
  #
  # See #generate for parameters and return value.
  #
  #: (*untyped, **untyped) -> Riffer::Agent::Response
  def self.generate(...)
    new.generate(...)
  end

  # Streams a response using a new agent instance.
  #
  # See #stream for parameters and return value.
  #
  #: (*untyped, **untyped) -> Enumerator[Riffer::StreamEvents::Base, void]
  def self.stream(...)
    new.stream(...)
  end

  # Registers a guardrail for input, output, or both phases.
  #
  # +phase+ - :before, :after, or :around.
  # +with+ - the guardrail class (must be subclass of Riffer::Guardrail).
  # +options+ - additional options passed to the guardrail.
  #
  # Raises Riffer::ArgumentError if phase is invalid or guardrail is not a Guardrail class.
  #: (Symbol, with: singleton(Riffer::Guardrail), **untyped) -> void
  def self.guardrail(phase, with:, **options)
    valid_phases = [*Riffer::Guardrails::PHASES, :around]
    raise Riffer::ArgumentError, "Invalid guardrail phase: #{phase}" unless valid_phases.include?(phase)
    raise Riffer::ArgumentError, "Guardrail must be a Riffer::Guardrail subclass" unless with.is_a?(Class) && with <= Riffer::Guardrail

    @guardrails ||= {before: [], after: []}
    config = {class: with, options: options}

    case phase
    when :before
      @guardrails[:before] << config
    when :after
      @guardrails[:after] << config
    when :around
      @guardrails[:before] << config
      @guardrails[:after] << config
    end
  end

  # Returns the registered guardrail configs for a given phase.
  #
  # +phase+ - :before or :after.
  #
  #: (Symbol) -> Array[Hash[Symbol, untyped]]
  def self.guardrails_for(phase)
    @guardrails ||= {before: [], after: []}
    @guardrails[phase] || []
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
  #: () -> void
  def initialize
    @messages = []
    @message_callbacks = []
    @token_usage = nil
    @interrupted = false
    @model_string = self.class.model
    @instructions_text = self.class.instructions

    provider_name, model_name = @model_string.split("/", 2)

    raise Riffer::ArgumentError, "Invalid model string: #{@model_string}" unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }

    @provider_name = provider_name
    @model_name = model_name
  end

  # Generates a response from the agent.
  #
  #: ((String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]), ?tool_context: Hash[Symbol, untyped]?) -> Riffer::Agent::Response
  def generate(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    @resolved_tools = nil
    @interrupted = false
    initialize_messages(prompt_or_messages)

    all_modifications = [] #: Array[Riffer::Guardrails::Modification]

    tripwire, modifications = run_before_guardrails
    all_modifications.concat(modifications)
    return build_response("", tripwire: tripwire, modifications: all_modifications) if tripwire

    run_generate_loop(all_modifications)
  end

  # Streams a response from the agent.
  #
  #: ((String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]), ?tool_context: Hash[Symbol, untyped]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(prompt_or_messages, tool_context: nil)
    @tool_context = tool_context
    @resolved_tools = nil
    @interrupted = false
    initialize_messages(prompt_or_messages)

    Enumerator.new do |yielder|
      tripwire, modifications = run_before_guardrails
      modifications.each { |m| yielder << Riffer::StreamEvents::GuardrailModification.new(m) }

      if tripwire
        yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire)
        next
      end

      run_stream_loop(yielder)
    end
  end

  # Resumes an agent loop.
  #
  # When called without +messages+, continues using the existing in-memory
  # message history. When called with +messages+, reconstructs the agent
  # state from persisted data (useful for cross-process resume).
  #
  # Skips message initialization and before guardrails in both cases.
  #
  #: (?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?tool_context: Hash[Symbol, untyped]?) -> Riffer::Agent::Response
  def resume(messages: nil, tool_context: nil)
    restore_state(messages: messages, tool_context: tool_context)
    run_generate_loop(resume: true)
  end

  # Resumes an agent loop in streaming mode.
  #
  # Same as +resume+ but returns an Enumerator yielding stream events.
  #
  #: (?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?tool_context: Hash[Symbol, untyped]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def resume_stream(messages: nil, tool_context: nil)
    restore_state(messages: messages, tool_context: tool_context)

    Enumerator.new do |yielder|
      run_stream_loop(yielder, resume: true)
    end
  end

  # Registers a callback to be invoked when messages are added during generation.
  #
  # Raises Riffer::ArgumentError if no block is given.
  #
  #: () { (Riffer::Messages::Base) -> void } -> self
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?
    @message_callbacks << block
    self
  end

  private

  #: (?Array[Riffer::Guardrails::Modification], ?resume: bool) -> Riffer::Agent::Response
  def run_generate_loop(all_modifications = [], resume: false)
    step = 0

    reason = catch(:riffer_interrupt) do
      execute_pending_tool_calls if resume

      loop do
        response = call_llm
        step += 1

        track_token_usage(response.token_usage)

        processed_response, tripwire, modifications = run_after_guardrails(response)
        all_modifications.concat(modifications)

        return build_response("", tripwire: tripwire, modifications: all_modifications) if tripwire

        add_message(processed_response)

        break unless has_tool_calls?(processed_response)

        throw :riffer_interrupt, INTERRUPT_MAX_STEPS if step >= self.class.max_steps

        execute_tool_calls(processed_response)
      end

      return build_response(extract_final_response, modifications: all_modifications)
    end

    # catch returns the thrown value when throw :riffer_interrupt fires;
    # the return above exits on the successful (non-interrupted) path.
    @interrupted = true
    build_response(extract_final_response, modifications: all_modifications, interrupted: true, interrupt_reason: reason)
  end

  #: (Riffer::Messages::Base) -> void
  def add_message(message)
    @messages << message
    @message_callbacks.each { |callback| callback.call(message) }
  end

  #: (Riffer::TokenUsage?) -> void
  def track_token_usage(usage)
    return unless usage

    @token_usage = @token_usage ? @token_usage + usage : usage
  end

  #: ((String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base])) -> void
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

  #: (?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?tool_context: Hash[Symbol, untyped]?) -> void
  def restore_state(messages: nil, tool_context: nil)
    @messages = messages.map { |item| convert_to_message_object(item) } if messages
    @tool_context = tool_context if tool_context
    @interrupted = false
    @resolved_tools = nil
  end

  #: (Enumerator::Yielder, ?resume: bool) -> void
  def run_stream_loop(yielder, resume: false)
    step = 0

    completed = catch(:riffer_interrupt) do
      execute_pending_tool_calls if resume

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

        track_token_usage(accumulated_token_usage)
        step += 1

        processed_response, tripwire, modifications = run_after_guardrails(response)
        modifications.each { |m| yielder << Riffer::StreamEvents::GuardrailModification.new(m) }

        if tripwire
          yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire)
          break
        end

        add_message(processed_response)

        break unless has_tool_calls?(processed_response)

        throw :riffer_interrupt, INTERRUPT_MAX_STEPS if step >= self.class.max_steps

        execute_tool_calls(processed_response)
      end
      :completed
    end

    unless completed == :completed
      @interrupted = true
      yielder << Riffer::StreamEvents::Interrupt.new(reason: completed)
    end
  end

  #: () -> Riffer::Messages::Assistant
  def call_llm
    provider_instance.generate_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
      **self.class.model_options
    )
  end

  #: () -> Enumerator[Riffer::StreamEvents::Base, void]
  def call_llm_stream
    provider_instance.stream_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
      **self.class.model_options
    )
  end

  #: () -> Riffer::Providers::Base
  def provider_instance
    @provider_instance ||= begin
      provider_class = Riffer::Providers::Repository.find(@provider_name)
      raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless provider_class
      provider_class.new(**self.class.provider_options)
    end
  end

  #: (Riffer::Messages::Assistant) -> bool
  def has_tool_calls?(response)
    response.is_a?(Riffer::Messages::Assistant) && !response.tool_calls.empty?
  end

  #: (Riffer::Messages::Assistant) -> void
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

  # Executes tool calls left unfinished by a prior interrupt.
  #
  # When an interrupt fires mid-way through tool execution, some tool calls
  # from the last assistant message may not have been executed yet. This
  # method detects those gaps by comparing the tool call ids requested by the
  # last assistant message against the tool result messages that follow it,
  # then executes any that are missing.
  #
  #: () -> void
  def execute_pending_tool_calls
    # Find the most recent assistant message (the one whose tool calls
    # may be partially executed).
    last_assistant_idx = @messages.rindex { |m| m.is_a?(Riffer::Messages::Assistant) }
    return unless last_assistant_idx

    assistant = @messages[last_assistant_idx]
    return if assistant.tool_calls.empty?

    # Collect ids of tool calls that already have a result message
    # after the assistant message.
    executed_ids = @messages[(last_assistant_idx + 1)..].select { |m|
      m.is_a?(Riffer::Messages::Tool)
    }.map(&:tool_call_id)

    # Execute any tool calls whose id is not in the executed set.
    assistant.tool_calls.each do |tool_call|
      next if executed_ids.include?(tool_call.id)
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

  #: (Riffer::Messages::Assistant::ToolCall) -> Riffer::Tools::Response
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

  #: () -> Array[singleton(Riffer::Tool)]
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

  #: (String) -> singleton(Riffer::Tool)?
  def find_tool_class(name)
    resolved_tools.find { |tool_class| tool_class.name == name }
  end

  #: ((String | Hash[String, untyped])?) -> Hash[Symbol, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    args = arguments.is_a?(String) ? JSON.parse(arguments) : arguments
    args.transform_keys(&:to_sym)
  end

  #: () -> String
  def extract_final_response
    last_assistant_message = @messages.reverse.find { |msg| msg.is_a?(Riffer::Messages::Assistant) }
    last_assistant_message&.content || ""
  end

  #: () -> [Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run_before_guardrails
    guardrails = self.class.guardrails_for(:before)
    return [nil, []] if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: @tool_context)
    processed_messages, tripwire, modifications = runner.run(@messages)
    @messages = processed_messages unless tripwire
    [tripwire, modifications]
  end

  #: (Riffer::Messages::Assistant) -> [untyped, Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run_after_guardrails(response)
    guardrails = self.class.guardrails_for(:after)
    return [response, nil, []] if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: @tool_context)
    processed_response, tripwire, modifications = runner.run(response, messages: @messages)

    response_index = @messages.length
    modifications.each { |m| m.message_indices.map! { response_index } }

    [processed_response, tripwire, modifications]
  end

  #: (String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?) -> Riffer::Agent::Response
  def build_response(content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil)
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, interrupted: interrupted, interrupt_reason: interrupt_reason)
  end
end
