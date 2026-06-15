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
    # The enumerator body runs in its own fiber, where the fiber-local OTEL
    # context is empty — capture here so the run span parents to the caller's trace.
    trace_context = Riffer::Tracing.current_context
    Enumerator.new do |stream_yielder|
      Riffer::Tracing.with_context(trace_context) { run_loop(agent, stream_yielder: stream_yielder) }
    end
  end

  private

  #--
  #: (Riffer::Agent, ?stream_yielder: Enumerator::Yielder?) -> Riffer::Agent::Response
  def run_loop(agent, stream_yielder: nil)
    Riffer::Tracing.in_span("invoke_agent #{agent.class.identifier}", attributes: run_span_attributes(agent), kind: :internal) do |span|
      response = execute_run(agent, stream_yielder)
      record_run_outcome(span, response)
      response
    rescue => error
      # The backend records the exception and error status on the re-raise;
      # error.type is the one semconv attribute it doesn't set.
      span.set_attribute("error.type", error.class.name)
      raise
    end
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?) -> Riffer::Agent::Response
  def execute_run(agent, stream_yielder)
    all_modifications = [] #: Array[Riffer::Guardrails::Modification]
    run_usage = nil #: Riffer::Providers::TokenUsage?
    run_steps = 0

    run_before_guardrails(agent, stream_yielder, all_modifications) do |tripwire|
      return tripwire_response(agent, stream_yielder, tripwire, all_modifications, steps: run_steps)
    end

    skills = agent.context.skills
    consumer_on_activate = skills&.on_activate

    if stream_yielder && skills
      skills.on_activate = ->(name) {
        consumer_on_activate&.call(name)
        stream_yielder << Riffer::StreamEvents::SkillActivation.new(name)
      }
    end

    begin
      step = agent.session.steps

      reason = catch(:riffer_interrupt) do
        execute_pending_tool_calls(agent)

        loop do
          response = stream_yielder ? accumulate_streamed_response(agent, stream_yielder) : call_llm(agent)
          step += 1
          run_steps += 1
          track_token_usage(agent, response.token_usage)
          run_usage = sum_usage(run_usage, response.token_usage)

          processed_response = run_after_guardrails(agent, response, stream_yielder, all_modifications) do |tripwire|
            return tripwire_response(agent, stream_yielder, tripwire, all_modifications, token_usage: run_usage, steps: run_steps)
          end

          agent.session.add(processed_response)

          break unless processed_response.has_tool_calls?

          max_steps = agent.config.max_steps
          throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if max_steps && step >= max_steps

          execute_tool_calls(agent, processed_response)
        end

        return final_response(agent, all_modifications, token_usage: run_usage, steps: run_steps)
      end

      new_messages, filled = Riffer::Agent::Session::Repair.fill_orphans(agent.session.messages)
      agent.session.set(new_messages)
      stream_yielder << Riffer::StreamEvents::Interrupt.new(reason: reason, healed_tool_call_ids: filled) if stream_yielder
      final_response(agent, all_modifications, interrupted: true, interrupt_reason: reason, healed_tool_call_ids: filled, token_usage: run_usage, steps: run_steps)
    ensure
      # The stream wiring must not outlive the run — a leaked lambda would push
      # later harness-side activations into a dead Enumerator::Yielder.
      skills.on_activate = consumer_on_activate if stream_yielder && skills
    end
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder) -> Riffer::Messages::Assistant
  def accumulate_streamed_response(agent, stream_yielder)
    accumulated_content = ""
    accumulated_tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]
    accumulated_token_usage = nil #: Riffer::Providers::TokenUsage?
    accumulated_finish_reason = nil #: Symbol?

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
      when Riffer::StreamEvents::FinishReasonDone
        accumulated_finish_reason = event.finish_reason
      end
    end

    Riffer::Messages::Assistant.new(
      accumulated_content,
      tool_calls: accumulated_tool_calls,
      token_usage: accumulated_token_usage,
      finish_reason: accumulated_finish_reason
    )
  end

  #--
  #: (Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Guardrails::Modification]) -> void
  def record_modifications!(stream_yielder, all_modifications, new_modifications)
    all_modifications.concat(new_modifications)
    new_modifications.each { |m| stream_yielder << Riffer::StreamEvents::GuardrailModification.new(m) } if stream_yielder
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Riffer::Guardrails::Tripwire, Array[Riffer::Guardrails::Modification], ?token_usage: Riffer::Providers::TokenUsage?, ?steps: Integer) -> Riffer::Agent::Response
  def tripwire_response(agent, stream_yielder, tripwire, all_modifications, token_usage: nil, steps: 0)
    stream_yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire) if stream_yielder
    build_response(agent, "", tripwire: tripwire, modifications: all_modifications, token_usage: token_usage, steps: steps)
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
  #: (Riffer::Agent, Riffer::Messages::Assistant, ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall]) -> void
  def execute_tool_calls(agent, assistant_message, tool_calls: assistant_message.tool_calls)
    return if tool_calls.empty?

    results = agent.tool_runtime.execute(tool_calls, tools: effective_tools(agent), context: agent.context, assistant_message: assistant_message)

    inject_discovered_tools(agent, results)

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
  #: (Riffer::Agent, Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]) -> void
  def inject_discovered_tools(agent, results)
    to_inject = results.flat_map { |_, result|
      result.is_a?(Riffer::Mcp::SearchTool::Result) ? result.discovered_tools : [] #: Array[singleton(Riffer::Tool)]
    }
    return if to_inject.empty?

    agent.context.discover_tools(to_inject)
  end

  #--
  #: (Riffer::Agent) -> void
  def execute_pending_tool_calls(agent)
    assistant_message, pending = agent.session.pending_tool_calls
    execute_tool_calls(agent, assistant_message, tool_calls: pending) if assistant_message
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification]) { (Riffer::Guardrails::Tripwire) -> void } -> void
  def run_before_guardrails(agent, stream_yielder, all_modifications)
    guardrails = agent.config.guardrails_for(:before)
    return if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: agent.context)
    processed_messages, tripwire, modifications = runner.run(agent.session.messages)
    agent.session.set(processed_messages) unless tripwire
    record_modifications!(stream_yielder, all_modifications, modifications)
    yield tripwire if tripwire
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification]) { (Riffer::Guardrails::Tripwire) -> void } -> untyped
  def run_after_guardrails(agent, response, stream_yielder, all_modifications)
    guardrails = agent.config.guardrails_for(:after)
    return response if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: agent.context)
    processed_response, tripwire, modifications = runner.run(response, messages: agent.session.messages)

    response_index = agent.session.messages.length
    modifications.each { |m| m.message_indices.map! { response_index } }

    record_modifications!(stream_yielder, all_modifications, modifications)
    yield tripwire if tripwire

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

  #--
  #: (Riffer::Agent, String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?healed_tool_call_ids: Array[String], ?token_usage: Riffer::Providers::TokenUsage?, ?steps: Integer) -> Riffer::Agent::Response
  def build_response(agent, content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil, structured_output: nil, healed_tool_call_ids: [], token_usage: nil, steps: 0)
    messages = agent.session.messages
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, interrupted: interrupted, interrupt_reason: interrupt_reason, structured_output: structured_output, messages: messages.frozen? ? messages : messages.dup.freeze, healed_tool_call_ids: healed_tool_call_ids, token_usage: token_usage, steps: steps)
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

    agent.context.token_usage = sum_usage(agent.context.token_usage, usage)
  end

  #--
  #: (Riffer::Providers::TokenUsage?, Riffer::Providers::TokenUsage?) -> Riffer::Providers::TokenUsage?
  def sum_usage(current, usage)
    return current unless usage

    current ? current + usage : usage
  end

  #--
  #: (Riffer::Agent) -> Hash[String, untyped]
  def run_span_attributes(agent)
    {
      "gen_ai.operation.name" => "invoke_agent",
      "gen_ai.agent.name" => agent.class.identifier,
      "gen_ai.provider.name" => agent.provider.class.semconv_provider_name,
      "gen_ai.request.model" => agent.model_name
    }
  end

  #--
  #: (Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span, Riffer::Agent::Response) -> void
  def record_run_outcome(span, response)
    span.set_attribute("riffer.steps", response.steps)
    Riffer::Tracing.record_usage(span, response.token_usage)

    span.set_attribute("riffer.interrupt.reason", response.interrupt_reason.to_s) if response.interrupt_reason

    tripwire = response.tripwire
    return unless tripwire

    guardrail_name = tripwire.guardrail.name
    span.set_attribute("riffer.tripwire.guardrail", guardrail_name) if guardrail_name
    span.set_attribute("riffer.tripwire.reason", tripwire.reason)
    span.set_attribute("riffer.tripwire.phase", tripwire.phase.to_s)
  end
end
