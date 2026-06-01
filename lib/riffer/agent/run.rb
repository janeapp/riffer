# frozen_string_literal: true
# rbs_inline: enabled

# The generation loop — a pure module of functions over an +agent+, which owns
# every per-call value; Run just orchestrates.
module Riffer::Agent::Run
  extend self

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
    started = monotonic_now
    all_modifications = [] #: Array[Riffer::Guardrails::Modification]
    all_timings = [] #: Array[Riffer::Timing]

    run_before_guardrails(agent, stream_yielder, all_modifications, all_timings, started) { |tripped| return tripped }

    skills = agent.context.skills

    if stream_yielder && skills
      skills.on_activate = ->(name) { stream_yielder << Riffer::StreamEvents::SkillActivation.new(name) }
    end

    step = agent.session.steps

    reason = catch(:riffer_interrupt) do
      execute_pending_tool_calls(agent, stream_yielder, all_timings)

      loop do
        step += 1
        response = perform_llm_call(agent, step, stream_yielder, all_timings)
        track_token_usage(agent, response.token_usage)

        processed_response = run_after_guardrails(agent, response, stream_yielder, all_modifications, all_timings, started) { |tripped| return tripped }

        agent.session.add(processed_response)

        break unless processed_response.has_tool_calls?

        max_steps = agent.config.max_steps
        throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if max_steps && step >= max_steps

        execute_tool_calls(agent, processed_response, stream_yielder, all_timings)
      end

      return final_response(agent, all_modifications, all_timings, started)
    end

    new_messages, filled = Riffer::Agent::Session::Repair.fill_orphans(agent.session.messages)
    agent.session.set(new_messages)
    stream_yielder << Riffer::StreamEvents::Interrupt.new(reason: reason, healed_tool_call_ids: filled) if stream_yielder
    final_response(agent, all_modifications, all_timings, started, interrupted: true, interrupt_reason: reason, healed_tool_call_ids: filled)
  end

  # Returns the current monotonic clock reading, in seconds.
  #--
  #: () -> Float
  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Calls the LLM (streamed or not) and, when +Riffer.config.report_timings+ is
  # enabled, records a Riffer::Providers::Timing for the call — total duration
  # plus, for streamed calls, time-to-first-token.
  #--
  #: (Riffer::Agent, Integer, Enumerator::Yielder?, Array[Riffer::Timing]) -> Riffer::Messages::Assistant
  def perform_llm_call(agent, step, stream_yielder, all_timings)
    unless Riffer.config.report_timings
      return stream_yielder ? accumulate_streamed_response(agent, stream_yielder) : call_llm(agent)
    end

    started = monotonic_now
    first_content_at = nil #: Float?
    response = if stream_yielder
      accumulate_streamed_response(agent, stream_yielder, on_first_content: -> { first_content_at = monotonic_now })
    else
      call_llm(agent)
    end

    timing = Riffer::Providers::Timing.new(
      model: agent.model_name,
      step: step,
      duration: monotonic_now - started,
      ttft: first_content_at && (first_content_at - started)
    )
    record_timings!(stream_yielder, all_timings, [timing])
    response
  end

  # Consumes the provider's stream, yielding each event downstream and
  # accumulating the assistant message. When +on_first_content+ is given, it is
  # invoked once, on the first generated-content event (text, reasoning, or
  # tool-call delta) — used to capture time-to-first-token.
  #--
  #: (Riffer::Agent, Enumerator::Yielder, ?on_first_content: (^() -> void)?) -> Riffer::Messages::Assistant
  def accumulate_streamed_response(agent, stream_yielder, on_first_content: nil)
    accumulated_content = ""
    accumulated_tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]
    accumulated_token_usage = nil #: Riffer::Providers::TokenUsage?
    signaled_first = false

    call_llm_stream(agent).each do |event|
      stream_yielder << event

      if on_first_content && !signaled_first && first_content_event?(event)
        on_first_content.call
        signaled_first = true
      end

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

  # Returns true for the first generated-content events — text, reasoning, or
  # tool-call deltas — used to mark time-to-first-token.
  #--
  #: (Riffer::StreamEvents::Base) -> bool
  def first_content_event?(event)
    event.is_a?(Riffer::StreamEvents::TextDelta) ||
      event.is_a?(Riffer::StreamEvents::ReasoningDelta) ||
      event.is_a?(Riffer::StreamEvents::ToolCallDelta)
  end

  #--
  #: (Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Guardrails::Modification]) -> void
  def record_modifications!(stream_yielder, all_modifications, new_modifications)
    all_modifications.concat(new_modifications)
    new_modifications.each { |m| stream_yielder << Riffer::StreamEvents::GuardrailModification.new(m) } if stream_yielder
  end

  # Appends +new_timings+ to +all_timings+ and emits a +Timing+ event for each
  # one when streaming.
  #
  #--
  #: (Enumerator::Yielder?, Array[Riffer::Timing], Array[Riffer::Timing]) -> void
  def record_timings!(stream_yielder, all_timings, new_timings)
    all_timings.concat(new_timings)
    new_timings.each { |t| stream_yielder << Riffer::StreamEvents::Timing.new(t) } if stream_yielder
  end

  # Emits a +GuardrailTripwire+ event when streaming and returns the
  # short-circuit +Response+ for a tripped guardrail.
  #
  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Riffer::Guardrails::Tripwire, Array[Riffer::Guardrails::Modification], Array[Riffer::Timing], Float) -> Riffer::Agent::Response
  def tripwire_response(agent, stream_yielder, tripwire, all_modifications, all_timings, started)
    stream_yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire) if stream_yielder
    build_response(agent, "", started: started, tripwire: tripwire, modifications: all_modifications, timings: all_timings)
  end

  #--
  #: (Riffer::Agent, Array[Riffer::Guardrails::Modification], Array[Riffer::Timing], Float, **untyped) -> Riffer::Agent::Response
  def final_response(agent, all_modifications, all_timings, started, **extra)
    response = agent.session.final_assistant_message
    build_response(agent, response&.content || "", started: started, modifications: all_modifications, timings: all_timings, structured_output: validate_structured_output(agent, response), **extra)
  end

  #--
  #: (Riffer::Agent) -> Riffer::Messages::Assistant
  def call_llm(agent)
    agent.provider.generate_text(
      messages: agent.session.messages,
      model: agent.model_name,
      tools: effective_tools(agent),
      **merged_model_options(agent)
    )
  end

  #--
  #: (Riffer::Agent) -> Enumerator[Riffer::StreamEvents::Base, void]
  def call_llm_stream(agent)
    agent.provider.stream_text(
      messages: agent.session.messages,
      model: agent.model_name,
      tools: effective_tools(agent),
      **merged_model_options(agent)
    )
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, Enumerator::Yielder?, Array[Riffer::Timing], ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall]) -> void
  def execute_tool_calls(agent, assistant_message, stream_yielder, all_timings, tool_calls: assistant_message.tool_calls)
    return if tool_calls.empty?

    results = agent.tool_runtime.execute(tool_calls, tools: effective_tools(agent), context: agent.context, assistant_message: assistant_message)

    inject_discovered_tools(agent, results)

    timings = [] #: Array[Riffer::Timing]
    results.each do |tool_call, result, timing|
      agent.session.add(Riffer::Messages::Tool.new(
        result.content,
        tool_call_id: tool_call.call_id,
        name: tool_call.name,
        error: result.error_message,
        error_type: result.error_type
      ))
      timings << timing if timing
    end
    record_timings!(stream_yielder, all_timings, timings)
  end

  #--
  #: (Riffer::Agent, Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response, Riffer::Tools::Timing?]]) -> void
  def inject_discovered_tools(agent, results)
    to_inject = results.flat_map { |_, result|
      result.is_a?(Riffer::Mcp::SearchTool::Result) ? result.discovered_tools : [] #: Array[singleton(Riffer::Tool)]
    }
    return if to_inject.empty?

    agent.context.discover_tools(to_inject)
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Array[Riffer::Timing]) -> void
  def execute_pending_tool_calls(agent, stream_yielder, all_timings)
    assistant_message, pending = agent.session.pending_tool_calls
    execute_tool_calls(agent, assistant_message, stream_yielder, all_timings, tool_calls: pending) if assistant_message
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Timing], Float) { (Riffer::Agent::Response) -> void } -> void
  def run_before_guardrails(agent, stream_yielder, all_modifications, all_timings, started)
    guardrails = agent.config.guardrails_for(:before)
    return if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: agent.context, measure_timings: Riffer.config.report_timings)
    processed_messages, tripwire, modifications, timings = runner.run(agent.session.messages)
    agent.session.set(processed_messages) unless tripwire
    record_modifications!(stream_yielder, all_modifications, modifications)
    record_timings!(stream_yielder, all_timings, timings)
    yield tripwire_response(agent, stream_yielder, tripwire, all_modifications, all_timings, started) if tripwire
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Timing], Float) { (Riffer::Agent::Response) -> void } -> untyped
  def run_after_guardrails(agent, response, stream_yielder, all_modifications, all_timings, started)
    guardrails = agent.config.guardrails_for(:after)
    return response if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: agent.context, measure_timings: Riffer.config.report_timings)
    processed_response, tripwire, modifications, timings = runner.run(response, messages: agent.session.messages)

    response_index = agent.session.messages.length
    modifications.each { |m| m.message_indices.map! { response_index } }

    record_modifications!(stream_yielder, all_modifications, modifications)
    record_timings!(stream_yielder, all_timings, timings)
    yield tripwire_response(agent, stream_yielder, tripwire, all_modifications, all_timings, started) if tripwire

    processed_response
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant?) -> Hash[Symbol, untyped]?
  def validate_structured_output(agent, response)
    return unless response&.structured_output? && agent.structured_output

    agent.structured_output.parse_and_validate(response.content).object
  end

  #--
  #: (Riffer::Agent) -> Array[singleton(Riffer::Tool)]
  def effective_tools(agent)
    discovered = agent.context.discovered_tools || []
    discovered.empty? ? agent.tools : agent.tools + discovered
  end

  #--
  #: (Riffer::Agent) -> Hash[Symbol, untyped]
  def merged_model_options(agent)
    opts = agent.config.model_options.dup
    opts[:structured_output] = agent.structured_output if agent.structured_output
    opts
  end

  # Builds the +Response+. When +started+ is given (always, inside the
  # generation loop), the total run +duration+ is stamped from it with a fresh
  # monotonic reading — independent of +Riffer.config.report_timings+.
  #--
  #: (Riffer::Agent, String, ?started: Float?, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?timings: Array[Riffer::Timing], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?healed_tool_call_ids: Array[String]) -> Riffer::Agent::Response
  def build_response(agent, content, started: nil, tripwire: nil, modifications: [], timings: [], interrupted: false, interrupt_reason: nil, structured_output: nil, healed_tool_call_ids: [])
    messages = agent.session.messages
    duration = started && (monotonic_now - started)
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, timings: timings, duration: duration, interrupted: interrupted, interrupt_reason: interrupt_reason, structured_output: structured_output, messages: messages.frozen? ? messages : messages.dup.freeze, healed_tool_call_ids: healed_tool_call_ids)
  end

  # Raises when +files+ are supplied without a +prompt+ — the provider needs
  # text to anchor the attachments.
  #--
  #: (Riffer::Agent, String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> void
  def append_user_message(agent, prompt, files: nil)
    raise Riffer::ArgumentError, "files: requires a prompt" if files && !files.empty? && prompt.nil?
    return unless prompt

    file_parts = (files || []).map { |f| Riffer::Messages::FilePart.from_hash(f) }
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
