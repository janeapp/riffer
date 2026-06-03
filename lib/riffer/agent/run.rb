# frozen_string_literal: true
# rbs_inline: enabled

# The generation loop — a pure module of functions over an +agent+, which owns
# every per-call value; Run just orchestrates.
module Riffer::Agent::Run
  extend self
  include Riffer::Messages::Converter

  # Runs the generate loop for the given agent. See Riffer::Agent#generate
  # for prompt/files semantics.
  #
  #--
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Riffer::Agent::Response
  def generate(agent:, prompt: nil, files: nil)
    append_user_message(agent, prompt, files: files)
    run_loop(agent)
  end

  # Runs the streaming loop for the given agent. See Riffer::Agent#stream
  # for prompt/files semantics.
  #
  #--
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(agent:, prompt: nil, files: nil)
    append_user_message(agent, prompt, files: files)
    Enumerator.new { |stream_yielder| run_loop(agent, stream_yielder: stream_yielder) }
  end

  private

  #--
  #: (Riffer::Agent, ?stream_yielder: Enumerator::Yielder?) -> Riffer::Agent::Response
  def run_loop(agent, stream_yielder: nil)
    all_modifications = [] #: Array[Riffer::Guardrails::Modification]

    run_before_guardrails(agent, stream_yielder, all_modifications) { |tripped| return tripped }

    skills = agent.context.skills

    if stream_yielder && skills
      skills.on_activate = ->(name) { stream_yielder << Riffer::StreamEvents::SkillActivation.new(name) }
    end

    step = agent.session.steps

    reason = catch(:riffer_interrupt) do
      execute_pending_tool_calls(agent)

      loop do
        response = stream_yielder ? accumulate_streamed_response(agent, stream_yielder) : call_llm(agent)
        step += 1
        track_token_usage(agent, response.token_usage)

        processed_response = run_after_guardrails(agent, response, stream_yielder, all_modifications) { |tripped| return tripped }

        agent.session.add(processed_response)

        break unless processed_response.has_tool_calls?

        max_steps = agent.config.max_steps
        throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if max_steps && step >= max_steps

        execute_tool_calls(agent, processed_response)
      end

      return final_response(agent, all_modifications)
    end

    new_messages, filled = Riffer::Agent::Session::Repair.fill_orphans(agent.session.messages)
    agent.session.set(new_messages)
    stream_yielder << Riffer::StreamEvents::Interrupt.new(reason: reason, healed_tool_call_ids: filled) if stream_yielder
    final_response(agent, all_modifications, interrupted: true, interrupt_reason: reason, healed_tool_call_ids: filled)
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder) -> Riffer::Messages::Assistant
  def accumulate_streamed_response(agent, stream_yielder)
    accumulated_content = ""
    accumulated_tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]
    accumulated_token_usage = nil #: Riffer::Providers::TokenUsage?

    call_llm_stream(agent).each do |event|
      stream_yielder << event

      case event
      when Riffer::StreamEvents::TextDelta
        accumulated_content += event.content
      when Riffer::StreamEvents::TextDone
        accumulated_content = event.content
      when Riffer::StreamEvents::ToolCallDone
        accumulated_tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          call_id: event.call_id,
          name: event.name,
          arguments: event.arguments
        )
      when Riffer::StreamEvents::TokenUsageDone
        accumulated_token_usage = event.token_usage
      end
    end

    Riffer::Messages::Assistant.new(
      accumulated_content,
      tool_calls: accumulated_tool_calls,
      token_usage: accumulated_token_usage
    )
  end

  #--
  #: (Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Guardrails::Modification]) -> void
  def record_modifications!(stream_yielder, all_modifications, new_modifications)
    all_modifications.concat(new_modifications)
    new_modifications.each { |m| stream_yielder << Riffer::StreamEvents::GuardrailModification.new(m) } if stream_yielder
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Riffer::Guardrails::Tripwire, Array[Riffer::Guardrails::Modification]) -> Riffer::Agent::Response
  def tripwire_response(agent, stream_yielder, tripwire, all_modifications)
    stream_yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire) if stream_yielder
    build_response(agent, "", tripwire: tripwire, modifications: all_modifications)
  end

  #--
  #: (Riffer::Agent, Array[Riffer::Guardrails::Modification], **untyped) -> Riffer::Agent::Response
  def final_response(agent, all_modifications, **extra)
    response = agent.session.final_assistant_message
    build_response(agent, response&.content || "", modifications: all_modifications, structured_output: validate_structured_output(agent, response), **extra)
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

  #--
  #: (Riffer::Agent) -> void
  def execute_pending_tool_calls(agent)
    assistant_message, pending = agent.session.pending_tool_calls
    execute_tool_calls(agent, assistant_message, tool_calls: pending) if assistant_message
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification]) { (Riffer::Agent::Response) -> void } -> void
  def run_before_guardrails(agent, stream_yielder, all_modifications)
    guardrails = agent.config.guardrails_for(:before)
    return if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: agent.context)
    processed_messages, tripwire, modifications = runner.run(agent.session.messages)
    agent.session.set(processed_messages) unless tripwire
    record_modifications!(stream_yielder, all_modifications, modifications)
    yield tripwire_response(agent, stream_yielder, tripwire, all_modifications) if tripwire
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification]) { (Riffer::Agent::Response) -> void } -> untyped
  def run_after_guardrails(agent, response, stream_yielder, all_modifications)
    guardrails = agent.config.guardrails_for(:after)
    return response if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: agent.context)
    processed_response, tripwire, modifications = runner.run(response, messages: agent.session.messages)

    response_index = agent.session.messages.length
    modifications.each { |m| m.message_indices.map! { response_index } }

    record_modifications!(stream_yielder, all_modifications, modifications)
    yield tripwire_response(agent, stream_yielder, tripwire, all_modifications) if tripwire

    processed_response
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
  #: (Riffer::Agent, String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?healed_tool_call_ids: Array[String]) -> Riffer::Agent::Response
  def build_response(agent, content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil, structured_output: nil, healed_tool_call_ids: [])
    messages = agent.session.messages
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, interrupted: interrupted, interrupt_reason: interrupt_reason, structured_output: structured_output, messages: messages.frozen? ? messages : messages.dup.freeze, healed_tool_call_ids: healed_tool_call_ids)
  end

  # Raises when +files+ are supplied without a +prompt+ — the provider needs
  # text to anchor the attachments.
  #--
  #: (Riffer::Agent, String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> void
  def append_user_message(agent, prompt, files: nil)
    raise Riffer::ArgumentError, "files: requires a prompt" if files && !files.empty? && prompt.nil?
    return unless prompt

    file_parts = (files || []).map { |f| convert_to_file_part(f) }
    agent.session.add(Riffer::Messages::User.new(prompt, files: file_parts), silent: true)
  end

  #--
  #: (Riffer::Agent, Riffer::Providers::TokenUsage?) -> void
  def track_token_usage(agent, usage)
    return unless usage

    current = agent.context.token_usage
    agent.context.token_usage = current ? current + usage : usage
  end
end
