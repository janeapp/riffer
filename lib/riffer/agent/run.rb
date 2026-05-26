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
    append_user_message(agent, prompt, files: files)
    run_loop(agent)
  end

  # Runs the streaming loop for the given agent. See Riffer::Agent#stream
  # for prompt/files semantics.
  #
  #--
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(agent:, prompt: nil, files: nil)
    append_user_message(agent, prompt, files: files)
    Enumerator.new { |stream_yielder| run_loop(agent, stream_yielder: stream_yielder) }
  end

  private

  # The generation loop. When +stream_yielder+ is provided, per-step events are
  # pushed to it (and +stream+ discards the return value). When +stream_yielder+
  # is +nil+, no events are emitted and +generate+ returns the Response
  # directly. The two modes share every step of the loop — the only
  # divergences are the LLM call shape (atomic vs. accumulated stream)
  # and whether per-step events are emitted.
  #
  #--
  #: (Riffer::Agent, ?stream_yielder: Enumerator::Yielder?) -> Riffer::Agent::Response
  def run_loop(agent, stream_yielder: nil)
    all_modifications = [] #: Array[Riffer::Guardrails::Modification]

    run_before_guardrails(agent, stream_yielder, all_modifications) { |tripped| return tripped }

    skills = agent.context[:skills]

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

        throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if step >= agent.config.max_steps

        execute_tool_calls(agent, processed_response)
      end

      return final_response(agent, all_modifications)
    end

    # catch returns the thrown value when throw :riffer_interrupt fires;
    # the return above exits on the successful (non-interrupted) path.
    new_messages, filled = Riffer::Session::Repair.fill_orphans(agent.session.messages)
    agent.session.set(new_messages)
    stream_yielder << Riffer::StreamEvents::Interrupt.new(reason: reason, healed_tool_call_ids: filled) if stream_yielder
    final_response(agent, all_modifications, interrupted: true, interrupt_reason: reason, healed_tool_call_ids: filled)
  end

  # Consumes one provider stream, forwarding every event to +stream_yielder+
  # and folding it into an +Assistant+ message.
  #
  #--
  #: (Riffer::Agent, Enumerator::Yielder) -> Riffer::Messages::Assistant
  def accumulate_streamed_response(agent, stream_yielder)
    accumulated_content = ""
    accumulated_tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]
    accumulated_token_usage = nil #: Riffer::TokenUsage?

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

  # Appends +new_modifications+ to +all_modifications+ and emits a
  # +GuardrailModification+ event for each one when streaming.
  #
  #--
  #: (Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Guardrails::Modification]) -> void
  def record_modifications!(stream_yielder, all_modifications, new_modifications)
    all_modifications.concat(new_modifications)
    new_modifications.each { |m| stream_yielder << Riffer::StreamEvents::GuardrailModification.new(m) } if stream_yielder
  end

  # Emits a +GuardrailTripwire+ event when streaming and returns the
  # short-circuit +Response+ for a tripped guardrail.
  #
  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Riffer::Guardrails::Tripwire, Array[Riffer::Guardrails::Modification]) -> Riffer::Agent::Response
  def tripwire_response(agent, stream_yielder, tripwire, all_modifications)
    stream_yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire) if stream_yielder
    build_response(agent, "", tripwire: tripwire, modifications: all_modifications)
  end

  # Builds the final +Response+ from the session's last assistant
  # message, validating structured output when configured. +extra+
  # carries the interrupt-only fields (+interrupted:+, +interrupt_reason:+,
  # +healed_tool_call_ids:+) on the interrupt exit path.
  #
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

  # Runs the +:before+ guardrail phase. Records any modifications into
  # +all_modifications+ (and emits them when streaming). When a tripwire
  # fires, yields the short-circuit +Response+ — the caller's block is
  # expected to +return+ it from +run_loop+.
  #
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

  # Runs the +:after+ guardrail phase against the assistant +response+.
  # Records any modifications into +all_modifications+ (and emits them
  # when streaming). When a tripwire fires, yields the short-circuit
  # +Response+ — the caller's block is expected to +return+ it from
  # +run_loop+. Otherwise returns the post-guardrails assistant message.
  #
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

  # Appends a +User+ message to the session. No-ops when +prompt+ is nil
  # and +files+ is empty (the caller had nothing to add). Raises when
  # +files+ are supplied without a +prompt+ — the provider needs text to
  # anchor the attachments.
  #
  #--
  #: (Riffer::Agent, String?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> void
  def append_user_message(agent, prompt, files: nil)
    raise Riffer::ArgumentError, "files: requires a prompt" if files && !files.empty? && prompt.nil?
    return unless prompt

    file_parts = (files || []).map { |f| convert_to_file_part(f) }
    agent.session.add(Riffer::Messages::User.new(prompt, files: file_parts), silent: true)
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
