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
  #--
  #: (?String?) -> String
  def self.identifier(value = nil)
    return @identifier || class_name_to_path(name) if value.nil?
    @identifier = value.to_s
  end

  # Gets or sets the model string (e.g., "openai/gpt-4o") or Proc.
  #
  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.model(model_string_or_proc = nil)
    return @model if model_string_or_proc.nil?

    if model_string_or_proc.is_a?(Proc)
      @model = model_string_or_proc
    else
      validate_is_string!(model_string_or_proc, "model")
      @model = model_string_or_proc
    end
  end

  # Gets or sets the agent instructions.
  #
  # Accepts a static string or a Proc for dynamic instructions.
  # When a Proc is given, it is called at generate time and receives
  # the +context+ hash (which may be +nil+).
  #
  #   instructions "You are a helpful assistant."
  #
  #   instructions -> (context) {
  #     "You are assisting #{context[:name]}"
  #   }
  #
  #--
  #: (?(String | Proc)?) -> (String | Proc)?
  def self.instructions(instructions_or_proc = nil)
    return @instructions if instructions_or_proc.nil?

    if instructions_or_proc.is_a?(Proc)
      @instructions = instructions_or_proc
    else
      validate_is_string!(instructions_or_proc, "instructions")
      @instructions = instructions_or_proc
    end
  end

  # Gets or sets provider options passed to the provider client.
  #
  #--
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.provider_options(options = nil)
    return @provider_options || {} if options.nil?
    @provider_options = options
  end

  # Gets or sets model options passed to generate_text/stream_text.
  #
  #--
  #: (?Hash[Symbol, untyped]?) -> Hash[Symbol, untyped]
  def self.model_options(options = nil)
    return @model_options || {} if options.nil?
    @model_options = options
  end

  # Gets or sets the structured output schema for this agent.
  #
  # Accepts a Riffer::Params instance or a block evaluated against a new Params.
  #
  #--
  #: (?Riffer::Params?) ?{ () -> void } -> Riffer::Params?
  def self.structured_output(params = nil, &block)
    if block
      @structured_output = Riffer::Params.new
      @structured_output.instance_eval(&block)
    elsif params.nil?
      @structured_output
    else
      raise Riffer::ArgumentError, "structured_output must be a Riffer::Params" unless params.is_a?(Riffer::Params)
      @structured_output = params
    end
  end

  # Gets or sets the maximum number of LLM call steps in the tool-use loop.
  #
  # Defaults to DEFAULT_MAX_STEPS (16). Set to +Float::INFINITY+ for
  # unlimited steps.
  #
  #--
  #: (?Numeric?) -> Numeric
  def self.max_steps(value = nil)
    return @max_steps || DEFAULT_MAX_STEPS if value.nil?
    @max_steps = value
  end

  # Gets or sets the tools used by this agent.
  #
  #--
  #: (?(Array[singleton(Riffer::Tool)] | Proc)?) -> (Array[singleton(Riffer::Tool)] | Proc)?
  def self.uses_tools(tools_or_lambda = nil)
    return @tools_config if tools_or_lambda.nil?
    @tools_config = tools_or_lambda
  end

  # Returns the tool classes the LLM should see for this agent.
  #
  # Class-level companion to the instance #resolved_tools. Resolves the
  # Proc form of +uses_tools+ and appends the skill activation tool when
  # a +skills+ block is configured. Does not read the skills backend —
  # the LLM-facing tool schema reflects class-level intent, not the
  # runtime state of any backend.
  #
  # When +uses_tools+ is a Proc, +context+ is forwarded to it.
  #
  # The activation tool class is resolved from the agent's
  # <tt>skills do; activate_tool ...; end</tt> override when set, otherwise
  # from <tt>Riffer.config.skills.default_activate_tool</tt>.
  #
  # Raises Riffer::ArgumentError on tool name conflicts with the skill
  # activation tool.
  #
  #--
  #: (?context: Hash[Symbol, untyped]?) -> Array[singleton(Riffer::Tool)]
  def self.resolved_tool_classes(context: nil)
    base = resolve_uses_tools_config(context)
    return base unless skills

    skill_activate_tool_class = skills.activate_tool || Riffer.config.skills.default_activate_tool
    if base.any? { |t| t.name == skill_activate_tool_class.name }
      raise Riffer::ArgumentError, "Tool name conflict with skill tools: #{skill_activate_tool_class.name}"
    end
    base + [skill_activate_tool_class]
  end

  #--
  #: (Hash[Symbol, untyped]?) -> Array[singleton(Riffer::Tool)]
  def self.resolve_uses_tools_config(context)
    config = uses_tools
    return [] if config.nil?
    return config unless config.is_a?(Proc)
    config.arity.zero? ? config.call : config.call(context)
  end
  private_class_method :resolve_uses_tools_config

  # Gets or sets the tool runtime for this agent.
  #
  # Accepts a Riffer::ToolRuntime subclass, a Riffer::ToolRuntime instance,
  # or a Proc.
  #
  # Inherited by subclasses. When unset, walks the ancestor chain and
  # falls back to the global <tt>Riffer.config.tool_runtime</tt>.
  #
  #--
  #: (?(singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)?) -> (singleton(Riffer::ToolRuntime) | Riffer::ToolRuntime | Proc)?
  def self.tool_runtime(value = nil)
    if value.nil?
      return @tool_runtime if instance_variable_defined?(:@tool_runtime)
      superclass.respond_to?(:tool_runtime) ? superclass.tool_runtime : nil
    else
      @tool_runtime = value
    end
  end

  # Configures skills for this agent via a block DSL.
  #
  # Returns the current Riffer::Skills::Config when called without a block.
  #
  #   skills do
  #     backend Riffer::Skills::FilesystemBackend.new(".skills")
  #     adapter Riffer::Skills::XmlAdapter
  #     activate ["code-review"]
  #   end
  #
  #--
  #: () ?{ () -> void } -> Riffer::Skills::Config?
  def self.skills(&block)
    if block
      @skills_config = Riffer::Skills::Config.new
      @skills_config.instance_eval(&block)
    end
    @skills_config
  end

  # Finds an agent class by identifier.
  #
  #--
  #: (String) -> singleton(Riffer::Agent)?
  def self.find(identifier)
    all.find { |agent_class| agent_class.identifier == identifier.to_s }
  end

  # Returns all agent subclasses.
  #
  #--
  #: () -> Array[singleton(Riffer::Agent)]
  def self.all
    subclasses #: Array[singleton(Riffer::Agent)]
  end

  # Generates a response using a new agent instance.
  #
  # See #generate for parameters and return value.
  #
  #--
  #: (*untyped, **untyped) -> Riffer::Agent::Response
  def self.generate(...)
    new.generate(...)
  end

  # Streams a response using a new agent instance.
  #
  # See #stream for parameters and return value.
  #
  #--
  #: (*untyped, **untyped) -> Enumerator[Riffer::StreamEvents::Base, void]
  def self.stream(...)
    new.stream(...)
  end

  # Registers a guardrail for input, output, or both phases.
  #
  # [phase] :before, :after, or :around.
  # [with] the guardrail class (must be subclass of Riffer::Guardrail).
  # [options] additional options passed to the guardrail.
  #
  # Raises Riffer::ArgumentError if phase is invalid or guardrail is not a Guardrail class.
  #--
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
  # [phase] :before or :after.
  #
  #--
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
  #--
  #: () -> void
  def initialize
    @messages = []
    @message_callbacks = []
    @token_usage = nil
    @interrupted = false
    @model_config = self.class.model
    @instructions_config = self.class.instructions

    if @model_config.is_a?(Proc)
      @provider_name = nil
      @model_name = nil
    else
      parse_model_string!(@model_config)
    end
  end

  # Generates a response from the agent.
  #
  #--
  #: ((String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]), ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?, ?context: Hash[Symbol, untyped]?) -> Riffer::Agent::Response
  def generate(prompt_or_messages, files: nil, context: nil)
    @context = context
    prepare_run
    @structured_output = resolve_structured_output
    initialize_messages(prompt_or_messages, files: files)

    all_modifications = [] #: Array[Riffer::Guardrails::Modification]

    tripwire, modifications = run_before_guardrails
    all_modifications.concat(modifications)
    return build_response("", tripwire: tripwire, modifications: all_modifications) if tripwire

    run_generate_loop(all_modifications)
  end

  # Streams a response from the agent.
  #
  # Raises Riffer::ArgumentError if structured output is configured.
  #
  #--
  #: ((String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]), ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?, ?context: Hash[Symbol, untyped]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(prompt_or_messages, files: nil, context: nil)
    raise Riffer::ArgumentError, "Structured output is not supported with streaming. Use #generate instead." if self.class.structured_output

    @context = context
    prepare_run
    initialize_messages(prompt_or_messages, files: files)

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

  # Registers a callback to be invoked when messages are added during generation.
  #
  # Raises Riffer::ArgumentError if no block is given.
  #
  #--
  #: () { (Riffer::Messages::Base) -> void } -> self
  def on_message(&block)
    raise Riffer::ArgumentError, "on_message requires a block" unless block_given?
    @message_callbacks << block
    self
  end

  # Generates the instruction system message for this agent.
  #
  # Useful for database persistence workflows where the system messages
  # need to be stored independently.
  #
  # Returns +nil+ when no instructions are configured.
  #
  #--
  #: (?context: Hash[Symbol, untyped]?) -> Riffer::Messages::System?
  def generate_instruction_message(context: nil)
    build_instruction_message(context)
  end

  # Generates the skills catalog system message for this agent.
  #
  # Useful for database persistence workflows where the system messages
  # need to be stored independently.
  #
  # Returns +nil+ when no skills are configured or the catalog is empty.
  #
  #--
  #: (?context: Hash[Symbol, untyped]?) -> Riffer::Messages::System?
  def generate_skills_message(context: nil)
    build_skills_message(resolve_skills(context))
  end

  # Interrupts the agent loop.
  #
  # Call from an +on_message+ callback to cleanly interrupt the loop.
  # Equivalent to <tt>throw :riffer_interrupt, reason</tt>.
  #
  #--
  #: (?(String | Symbol)?) -> void
  def interrupt!(reason = nil)
    throw :riffer_interrupt, reason
  end

  private

  #--
  #: (?Array[Riffer::Guardrails::Modification]) -> Riffer::Agent::Response
  def run_generate_loop(all_modifications = [])
    step = count_assistant_messages

    reason = catch(:riffer_interrupt) do
      execute_pending_tool_calls

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

      response = extract_final_response

      return build_response(response&.content || "", modifications: all_modifications, structured_output: validate_structured_output(response))
    end

    # catch returns the thrown value when throw :riffer_interrupt fires;
    # the return above exits on the successful (non-interrupted) path.
    @interrupted = true
    response = extract_final_response

    build_response(response&.content || "", modifications: all_modifications, interrupted: true, interrupt_reason: reason, structured_output: validate_structured_output(response))
  end

  #--
  #: (Riffer::Messages::Base) -> void
  def add_message(message)
    @messages << message
    @message_callbacks.each { |callback| callback.call(message) }
  end

  #--
  #: (Riffer::TokenUsage?) -> void
  def track_token_usage(usage)
    return unless usage

    @token_usage = @token_usage ? @token_usage + usage : usage
  end

  #--
  #: ((String | Array[Hash[Symbol, untyped] | Riffer::Messages::Base]), ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> void
  def initialize_messages(prompt_or_messages, files: nil)
    if prompt_or_messages.is_a?(Array)
      raise Riffer::ArgumentError, "cannot pass an array of messages on an agent with existing messages; use a string to continue the conversation or a new agent instance to start fresh" if @messages.any?
      raise Riffer::ArgumentError, "cannot provide both files and messages; attach files to individual messages instead" if files && !files.empty?
      validate_seed_ids!(prompt_or_messages)
      @messages = prompt_or_messages.map { |item| convert_to_message_object(item) }
    elsif @messages.any?
      file_parts = (files || []).map { |f| convert_to_file_part(f) }
      @messages << Riffer::Messages::User.new(prompt_or_messages, files: file_parts)
    else
      @messages = []
      sys = build_instruction_message
      @messages << sys if sys
      skills = build_skills_message
      @messages << skills if skills
      file_parts = (files || []).map { |f| convert_to_file_part(f) }
      @messages << Riffer::Messages::User.new(prompt_or_messages, files: file_parts)
    end
  end

  #--
  #: (Array[Hash[Symbol, untyped] | Riffer::Messages::Base]) -> void
  def validate_seed_ids!(items)
    strategy = Riffer.config.message_id_strategy
    return if strategy == :none

    items.each_with_index do |item, idx|
      raw_id = case item
      when Hash then item[:id]
      when Riffer::Messages::Base then item.id
      else next # type errors surface later via convert_to_message_object
      end
      next unless raw_id.nil?
      raise Riffer::ArgumentError,
        "seeded message at index #{idx} is missing :id (required when Riffer.config.message_id_strategy = #{strategy.inspect})"
    end
  end

  #--
  #: (?Hash[Symbol, untyped]?) -> Riffer::Messages::System?
  def build_instruction_message(context = @context)
    content = generate_instructions(context)
    return nil if content.nil? || content.empty?
    Riffer::Messages::System.new(content)
  end

  #--
  #: (?Riffer::Skills::Context?) -> Riffer::Messages::System?
  def build_skills_message(skills_state = @skills_state)
    content = skills_state&.system_prompt
    return nil if content.nil? || content.empty?
    Riffer::Messages::System.new(content)
  end

  #--
  #: () -> Integer
  def count_assistant_messages
    @messages.count { |m| m.is_a?(Riffer::Messages::Assistant) }
  end

  #--
  #: (Enumerator::Yielder) -> void
  def run_stream_loop(yielder)
    step = count_assistant_messages

    if @skills_state
      @skills_state.on_activate = ->(name) { yielder << Riffer::StreamEvents::SkillActivation.new(name) }
    end

    completed = catch(:riffer_interrupt) do
      execute_pending_tool_calls

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

  #--
  #: () -> Riffer::Messages::Assistant
  def call_llm
    provider_instance.generate_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
      **merged_model_options
    )
  end

  #--
  #: () -> Enumerator[Riffer::StreamEvents::Base, void]
  def call_llm_stream
    provider_instance.stream_text(
      messages: @messages,
      model: @model_name,
      tools: resolved_tools,
      **merged_model_options
    )
  end

  #--
  #: () -> Riffer::Providers::Base
  def provider_instance
    @provider_instance ||= provider_class.new(**self.class.provider_options)
  end

  #--
  #: (Riffer::Messages::Assistant) -> bool
  def has_tool_calls?(response)
    response.is_a?(Riffer::Messages::Assistant) && !response.tool_calls.empty?
  end

  #--
  #: (Riffer::Messages::Assistant) -> void
  def execute_tool_calls(response)
    runtime = resolve_tool_runtime
    results = runtime.execute(response.tool_calls, tools: resolved_tools, context: @context)

    results.each do |tool_call, result|
      add_message(Riffer::Messages::Tool.new(
        result.content,
        tool_call_id: tool_call.call_id,
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
  #--
  #: () -> void
  # Executes tool calls from the last assistant message that don't yet
  # have a corresponding tool result. Safe to call unconditionally —
  # returns immediately when there is nothing pending.
  def execute_pending_tool_calls
    pending = pending_tool_calls
    return if pending.empty?

    runtime = resolve_tool_runtime
    results = runtime.execute(pending, tools: resolved_tools, context: @context)

    results.each do |tool_call, result|
      add_message(Riffer::Messages::Tool.new(
        result.content,
        tool_call_id: tool_call.call_id,
        name: tool_call.name,
        error: result.error_message,
        error_type: result.error_type
      ))
    end
  end

  def pending_tool_calls
    last_assistant_idx = @messages.rindex { |m| m.is_a?(Riffer::Messages::Assistant) }
    return [] unless last_assistant_idx

    assistant = @messages[last_assistant_idx]
    return [] if assistant.tool_calls.empty?

    executed_ids = @messages[(last_assistant_idx + 1)..].select { |m|
      m.is_a?(Riffer::Messages::Tool)
    }.map(&:tool_call_id)

    assistant.tool_calls.reject { |tc| executed_ids.include?(tc.call_id) }
  end

  #--
  #: () -> void
  def prepare_run
    @resolved_tools = nil
    @resolved_tool_runtime = nil
    clear_resolved_model
    @interrupted = false
    resolve_model
    @skills_state = resolve_skills
    @context = (@context || {}).merge(skills: @skills_state) if @skills_state
  end

  #--
  #: (untyped) -> void
  def parse_model_string!(model_string)
    raise Riffer::ArgumentError, "Invalid model string: #{model_string}" unless model_string.is_a?(String)
    provider_name, model_name = model_string.split("/", 2)
    raise Riffer::ArgumentError, "Invalid model string: #{model_string}" unless [provider_name, model_name].all? { |part| part.is_a?(String) && !part.strip.empty? }
    @provider_name = provider_name
    @model_name = model_name
  end

  #--
  #: () -> void
  def clear_resolved_model
    @resolved_model = nil
    @provider_instance = nil if @model_config.is_a?(Proc)
  end

  #--
  #: (?Hash[Symbol, untyped]?) -> String?
  def generate_instructions(context = @context)
    if @instructions_config.is_a?(Proc)
      (@instructions_config.arity == 0) ? @instructions_config.call : @instructions_config.call(context)
    else
      @instructions_config
    end
  end

  attr_reader :resolved_model #: String?

  #--
  #: () -> String
  def resolve_model
    @resolved_model ||= if @model_config.is_a?(Proc)
      model_string = (@model_config.arity == 0) ? @model_config.call : @model_config.call(@context)
      parse_model_string!(model_string)
      model_string
    else
      @model_config
    end
  end

  #--
  #: () -> Array[singleton(Riffer::Tool)]
  def resolved_tools
    @resolved_tools ||= self.class.resolved_tool_classes(context: @context)
  end

  #--
  #: () -> Riffer::ToolRuntime
  def resolve_tool_runtime
    @resolved_tool_runtime ||= begin
      config = self.class.tool_runtime || Riffer.config.tool_runtime

      runtime = if config.is_a?(Proc)
        (config.arity == 0) ? config.call : config.call(@context)
      else
        config
      end

      case runtime
      when Class then runtime.new
      when Riffer::ToolRuntime then runtime
      else raise Riffer::ArgumentError, "Invalid tool_runtime: #{runtime.inspect}"
      end
    end
  end

  # Resolves the skills backend, lists skills, and selects an adapter.
  #
  # Returns nil if skills are not configured or empty.
  # Does not mutate instance state — callers are responsible for
  # assigning the returned context.
  #
  #--
  #: (?Hash[Symbol, untyped]?) -> Riffer::Skills::Context?
  def resolve_skills(context = @context)
    return nil unless self.class.skills

    backend = self.class.skills.backend || Riffer.config.skills.default_backend
    return nil unless backend

    backend = backend.is_a?(Proc) ? backend.call(context) : backend
    skills_list = backend.list_skills
    return nil if skills_list.empty?

    skills = skills_list.to_h { |s| [s.name, s] }
    adapter_class = self.class.skills.adapter || provider_class.skills_adapter(@model_name)
    skill_activate_tool_class = self.class.skills.activate_tool || Riffer.config.skills.default_activate_tool

    skills_context = Riffer::Skills::Context.new(
      backend: backend,
      skills: skills,
      adapter: adapter_class.new(skill_activate_tool: skill_activate_tool_class)
    )
    ctx = (context || {}).merge(skills: skills_context)

    activate = self.class.skills.activate
    if activate
      names = activate.is_a?(Proc) ? activate.call(ctx) : Array(activate)
      names.each { |name| skills_context.activate(name) }
    end

    skills_context
  end

  #--
  #: () -> singleton(Riffer::Providers::Base)
  def provider_class
    klass = Riffer::Providers::Repository.find(@provider_name)
    raise Riffer::ArgumentError, "Provider not found: #{@provider_name}" unless klass
    klass
  end

  #--
  #: () -> Riffer::Messages::Assistant?
  def extract_final_response
    # TODO: Replace with rfind when minimum Ruby is 4.0+
    # rubocop:disable Style/ReverseFind
    @messages.reverse.find { |msg| msg.is_a?(Riffer::Messages::Assistant) } #: Riffer::Messages::Assistant?
    # rubocop:enable Style/ReverseFind
  end

  #--
  #: () -> [Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run_before_guardrails
    guardrails = self.class.guardrails_for(:before)
    return [nil, []] if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: @context)
    processed_messages, tripwire, modifications = runner.run(@messages)
    @messages = processed_messages unless tripwire
    [tripwire, modifications]
  end

  #--
  #: (Riffer::Messages::Assistant) -> [untyped, Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run_after_guardrails(response)
    guardrails = self.class.guardrails_for(:after)
    return [response, nil, []] if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: @context)
    processed_response, tripwire, modifications = runner.run(response, messages: @messages)

    response_index = @messages.length
    modifications.each { |m| m.message_indices.map! { response_index } }

    [processed_response, tripwire, modifications]
  end

  #--
  #: (Riffer::Messages::Assistant?) -> Hash[Symbol, untyped]?
  def validate_structured_output(response)
    return unless response&.structured_output? && @structured_output

    @structured_output.parse_and_validate(response.content).object
  end

  #--
  #: () -> Riffer::StructuredOutput?
  def resolve_structured_output
    params = self.class.structured_output
    params ? Riffer::StructuredOutput.new(params) : nil
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def merged_model_options
    opts = self.class.model_options.dup
    opts[:structured_output] = @structured_output if @structured_output
    opts
  end

  #--
  #: (String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?) -> Riffer::Agent::Response
  def build_response(content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil, structured_output: nil)
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, interrupted: interrupted, interrupt_reason: interrupt_reason, structured_output: structured_output, messages: @messages.frozen? ? @messages : @messages.dup.freeze)
  end
end
