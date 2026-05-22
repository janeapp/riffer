# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Agent::Run is the generation loop. A pure module of functions over an
# +agent+ — Agent owns every per-call value (provider, model, tools, tool
# runtime, structured output, session, context); Run just orchestrates.
#
# Tools and user code see the agent's +context+ unchanged through the
# loop, so downstream tool runtimes can read +context[:agent]+ or
# +context[:skills]+. Cumulative token usage is mutated into
# +agent.context[:token_usage]+ as the loop progresses.
#
#   Riffer::Agent::Run.generate(agent: my_agent, prompt: "Hello")
#   Riffer::Agent::Run.stream(agent: my_agent, prompt: "Hello")
#
module Riffer::Agent::Run
  extend self
  include Riffer::Messages::Converter

  # Runs the generate loop for the given agent. See Riffer::Agent#generate
  # for prompt/files semantics.
  #
  #--
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> Riffer::Agent::Response
  def generate(agent:, prompt: nil, files: nil)
    raise Riffer::ArgumentError, "files: requires a prompt" if files && !files.empty? && prompt.nil?

    append_user_message(agent, prompt, files: files) if prompt

    all_modifications = [] #: Array[Riffer::Guardrails::Modification]

    tripwire, modifications = run_before_guardrails(agent)
    all_modifications.concat(modifications)
    return build_response(agent, "", tripwire: tripwire, modifications: all_modifications) if tripwire

    run_generate_loop(agent, all_modifications)
  end

  # Runs the streaming loop for the given agent. See Riffer::Agent#stream
  # for prompt/files semantics.
  #
  #--
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(agent:, prompt: nil, files: nil)
    raise Riffer::ArgumentError, "files: requires a prompt" if files && !files.empty? && prompt.nil?

    append_user_message(agent, prompt, files: files) if prompt

    Enumerator.new do |yielder|
      tripwire, modifications = run_before_guardrails(agent)
      modifications.each { |m| yielder << Riffer::StreamEvents::GuardrailModification.new(m) }

      if tripwire
        yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire)
        next
      end

      run_stream_loop(agent, yielder)
    end
  end

  private

  #--
  #: (Riffer::Agent, ?Array[Riffer::Guardrails::Modification]) -> Riffer::Agent::Response
  def run_generate_loop(agent, all_modifications = [])
    step = agent.session.count { |m| m.is_a?(Riffer::Messages::Assistant) }

    reason = catch(:riffer_interrupt) do
      execute_pending_tool_calls(agent)

      loop do
        response = call_llm(agent)
        step += 1

        track_token_usage(agent, response.token_usage)

        processed_response, tripwire, modifications = run_after_guardrails(agent, response)
        all_modifications.concat(modifications)

        return build_response(agent, "", tripwire: tripwire, modifications: all_modifications) if tripwire

        agent.session.add(processed_response)

        break unless has_tool_calls?(processed_response)

        throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if step >= agent.config.max_steps

        execute_tool_calls(agent, processed_response)
      end

      response = final_assistant_message(agent)

      return build_response(agent, response&.content || "", modifications: all_modifications, structured_output: validate_structured_output(agent, response))
    end

    # catch returns the thrown value when throw :riffer_interrupt fires;
    # the return above exits on the successful (non-interrupted) path.
    new_messages, filled = Riffer::Session::Repair.fill_orphans(agent.session.messages)
    agent.session.set(new_messages)
    response = final_assistant_message(agent)

    build_response(agent, response&.content || "", modifications: all_modifications, interrupted: true, interrupt_reason: reason, structured_output: validate_structured_output(agent, response), healed_tool_call_ids: filled)
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder) -> void
  def run_stream_loop(agent, yielder)
    step = agent.session.count { |m| m.is_a?(Riffer::Messages::Assistant) }

    skills = agent.context[:skills]
    if skills
      skills.on_activate = ->(name) { yielder << Riffer::StreamEvents::SkillActivation.new(name) }
    end

    completed = catch(:riffer_interrupt) do
      execute_pending_tool_calls(agent)

      loop do
        accumulated_content = ""
        accumulated_tool_calls = []
        accumulated_token_usage = nil
        current_tool_call = nil

        call_llm_stream(agent).each do |event|
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

        track_token_usage(agent, accumulated_token_usage)
        step += 1

        processed_response, tripwire, modifications = run_after_guardrails(agent, response)
        modifications.each { |m| yielder << Riffer::StreamEvents::GuardrailModification.new(m) }

        if tripwire
          yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire)
          break
        end

        agent.session.add(processed_response)

        break unless has_tool_calls?(processed_response)

        throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if step >= agent.config.max_steps

        execute_tool_calls(agent, processed_response)
      end
      :completed
    end

    unless completed == :completed
      new_messages, filled = Riffer::Session::Repair.fill_orphans(agent.session.messages)
      agent.session.set(new_messages)
      yielder << Riffer::StreamEvents::Interrupt.new(reason: completed, healed_tool_call_ids: filled)
    end
  end

  #--
  #: (Riffer::Agent) -> Riffer::Messages::Assistant
  def call_llm(agent)
    agent.provider.generate_text(
      messages: agent.session.messages,
      model: agent.model_name,
      tools: agent.tools,
      **merged_model_options(agent)
    )
  end

  #--
  #: (Riffer::Agent) -> Enumerator[Riffer::StreamEvents::Base, void]
  def call_llm_stream(agent)
    agent.provider.stream_text(
      messages: agent.session.messages,
      model: agent.model_name,
      tools: agent.tools,
      **merged_model_options(agent)
    )
  end

  #--
  #: (Riffer::Messages::Assistant) -> bool
  def has_tool_calls?(response)
    response.is_a?(Riffer::Messages::Assistant) && !response.tool_calls.empty?
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall]) -> void
  def execute_tool_calls(agent, assistant_message, tool_calls: assistant_message.tool_calls)
    return if tool_calls.empty?

    results = agent.tool_runtime.execute(tool_calls, tools: agent.tools, context: agent.context, assistant_message: assistant_message)

    results.each do |tool_call, result|
      agent.session.add(Riffer::Messages::Tool.new(
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
  # Detects gaps between the last assistant message's requested tool calls
  # and the tool result messages that follow it, executing any that are
  # missing. Safe to call unconditionally.
  #
  #--
  #: (Riffer::Agent) -> void
  def execute_pending_tool_calls(agent)
    assistant_message, pending = agent.session.pending_tool_calls
    execute_tool_calls(agent, assistant_message, tool_calls: pending) if assistant_message
  end

  #--
  #: (Riffer::Agent) -> [Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run_before_guardrails(agent)
    guardrails = agent.config.guardrails_for(:before)
    return [nil, []] if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: agent.context)
    processed_messages, tripwire, modifications = runner.run(agent.session.messages)
    agent.session.set(processed_messages) unless tripwire
    [tripwire, modifications]
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant) -> [untyped, Riffer::Guardrails::Tripwire?, Array[Riffer::Guardrails::Modification]]
  def run_after_guardrails(agent, response)
    guardrails = agent.config.guardrails_for(:after)
    return [response, nil, []] if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: agent.context)
    processed_response, tripwire, modifications = runner.run(response, messages: agent.session.messages)

    response_index = agent.session.messages.length
    modifications.each { |m| m.message_indices.map! { response_index } }

    [processed_response, tripwire, modifications]
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant?) -> Hash[Symbol, untyped]?
  def validate_structured_output(agent, response)
    return unless response&.structured_output? && agent.structured_output

    agent.structured_output.parse_and_validate(response.content).object
  end

  #--
  #: (Riffer::Agent) -> Hash[Symbol, untyped]
  def merged_model_options(agent)
    opts = agent.config.model_options.dup
    opts[:structured_output] = agent.structured_output if agent.structured_output
    opts
  end

  #--
  #: (Riffer::Agent) -> Riffer::Messages::Assistant?
  def final_assistant_message(agent)
    # TODO: Replace with rfind when minimum Ruby is 4.0+
    # rubocop:disable Style/ReverseFind
    agent.session.reverse_each.find { |msg| msg.is_a?(Riffer::Messages::Assistant) } #: Riffer::Messages::Assistant?
    # rubocop:enable Style/ReverseFind
  end

  #--
  #: (Riffer::Agent, String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?healed_tool_call_ids: Array[String]) -> Riffer::Agent::Response
  def build_response(agent, content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil, structured_output: nil, healed_tool_call_ids: [])
    messages = agent.session.messages
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, interrupted: interrupted, interrupt_reason: interrupt_reason, structured_output: structured_output, messages: messages.frozen? ? messages : messages.dup.freeze, healed_tool_call_ids: healed_tool_call_ids)
  end

  #--
  #: (Riffer::Agent, String, files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> void
  def append_user_message(agent, prompt, files:)
    file_parts = (files || []).map { |f| convert_to_file_part(f) }
    agent.session.set(agent.session.messages + [Riffer::Messages::User.new(prompt, files: file_parts)])
  end

  # Accumulates token usage into +agent.context[:token_usage]+. Mutates the
  # context Hash so cumulative usage persists across every run on the agent.
  #
  #--
  #: (Riffer::Agent, Riffer::TokenUsage?) -> void
  def track_token_usage(agent, usage)
    return unless usage

    current = agent.context[:token_usage]
    agent.context[:token_usage] = current ? current + usage : usage
  end
end
