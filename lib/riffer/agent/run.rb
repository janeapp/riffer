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
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, ?tags: Hash[(String | Symbol), untyped]) -> Riffer::Agent::Response
  def generate(agent:, prompt: nil, files: nil, tags: {})
    append_user_message(agent, prompt, files: files)
    run_loop(agent, tags: tags)
  end

  # Runs the streaming loop for the given agent. See Riffer::Agent#stream
  # for prompt/files semantics.
  #
  #--
  #: (agent: Riffer::Agent, ?prompt: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, ?tags: Hash[(String | Symbol), untyped]) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream(agent:, prompt: nil, files: nil, tags: {})
    append_user_message(agent, prompt, files: files)
    # The enumerator body runs in its own fiber, where the fiber-local OTEL
    # context is empty — capture here so the run span parents to the caller's
    # trace. tags ride as an ordinary argument captured in the closure, so they
    # cross the fiber boundary without any re-propagation.
    trace_context = Riffer::Tracing.current_context
    Enumerator.new do |stream_yielder|
      Riffer::Tracing.with_context(trace_context) { run_loop(agent, tags: tags, stream_yielder: stream_yielder) }
    end
  end

  private

  # Both +generate+ and +stream+ funnel here, so this is the single place raw
  # +tags+ are normalized. The clean <tt>String => String</tt> map is then
  # threaded to every span builder in the run as +riffer.tag.*+ and to each
  # provider call (via +merged_model_options+) for native request-metadata
  # mapping.
  #--
  #: (Riffer::Agent, ?tags: Hash[(String | Symbol), untyped]?, ?stream_yielder: Enumerator::Yielder?) -> Riffer::Agent::Response
  def run_loop(agent, tags: {}, stream_yielder: nil)
    tags = normalize_tags(tags)
    Riffer::Tracing.in_span("invoke_agent #{agent.class.identifier}", attributes: run_span_attributes(agent, tags),
                                                                      kind: :internal,) do |span|
      response = execute_run(agent, stream_yielder, tags)
      record_run_outcome(span, response)
      response
    rescue StandardError => e
      # The backend records the exception and error status on the re-raise;
      # error.type is the one semconv attribute it doesn't set.
      span.set_attribute("error.type", e.class.name)
      raise
    end
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, ?Hash[String, String]) -> Riffer::Agent::Response
  def execute_run(agent, stream_yielder, tags = {})
    all_modifications = [] #: Array[Riffer::Guardrails::Modification]
    run_usage = nil #: Riffer::Providers::TokenUsage?
    run_steps = 0

    run_before_guardrails(agent, stream_yielder, all_modifications, tags) do |tripwire|
      return tripwire_response(agent, stream_yielder, tripwire, all_modifications, steps: run_steps)
    end

    skills = agent.context.skills
    consumer_on_activate = skills&.on_activate

    if stream_yielder && skills
      skills.on_activate = lambda { |name|
        consumer_on_activate&.call(name)
        stream_yielder << Riffer::StreamEvents::SkillActivation.new(name)
      }
    end

    begin
      step = agent.session.steps

      reason = catch(:riffer_interrupt) do
        execute_pending_tool_calls(agent, tags)

        loop do
          response = stream_yielder ? accumulate_streamed_response(agent, stream_yielder, tags) : call_llm(agent, tags)
          step += 1
          run_steps += 1
          track_token_usage(agent, response.token_usage)
          run_usage = sum_usage(run_usage, response.token_usage)

          processed_response = run_after_guardrails(agent, response, stream_yielder, all_modifications,
                                                    tags,) do |tripwire|
            return tripwire_response(agent, stream_yielder, tripwire, all_modifications, token_usage: run_usage,
                                                                                         steps: run_steps,)
          end

          agent.session.add(processed_response)

          break unless processed_response.has_tool_calls?

          max_steps = agent.config.max_steps
          throw :riffer_interrupt, Riffer::Agent::INTERRUPT_MAX_STEPS if max_steps && step >= max_steps

          execute_tool_calls(agent, processed_response, tags: tags)
        end

        return final_response(agent, all_modifications, token_usage: run_usage, steps: run_steps)
      end

      new_messages, filled = Riffer::Agent::Session::Repair.fill_orphans(agent.session.messages)
      agent.session.set(new_messages)
      if stream_yielder
        stream_yielder << Riffer::StreamEvents::Interrupt.new(reason: reason,
                                                              healed_tool_call_ids: filled,)
      end
      final_response(agent, all_modifications, interrupted: true, interrupt_reason: reason,
                                               healed_tool_call_ids: filled, token_usage: run_usage, steps: run_steps,)
    ensure
      # The stream wiring must not outlive the run — a leaked lambda would push
      # later harness-side activations into a dead Enumerator::Yielder.
      skills.on_activate = consumer_on_activate if stream_yielder && skills
    end
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder, ?Hash[String, String]) -> Riffer::Messages::Assistant
  def accumulate_streamed_response(agent, stream_yielder, tags = {})
    accumulated_content = +""
    accumulated_tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]
    accumulated_token_usage = nil #: Riffer::Providers::TokenUsage?
    accumulated_finish_reason = nil #: Symbol?

    call_llm_stream(agent, tags).each do |event|
      stream_yielder << event

      case event
      when Riffer::StreamEvents::TextDelta
        # Append in place rather than += (which reallocates and copies the whole
        # buffer per delta, O(n^2) over a stream). accumulated_content stays an
        # owned buffer; replace (not =) on TextDone keeps it that way so a later
        # delta's << can never mutate the string held by a TextDone event.
        accumulated_content << event.content
      when Riffer::StreamEvents::TextDone
        accumulated_content.replace(event.content)
      when Riffer::StreamEvents::ToolCallDone
        accumulated_tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          call_id: event.call_id,
          name: event.name,
          arguments: event.arguments,
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
      finish_reason: accumulated_finish_reason,
    )
  end

  #--
  #: (Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], Array[Riffer::Guardrails::Modification]) -> void
  def record_modifications!(stream_yielder, all_modifications, new_modifications)
    all_modifications.concat(new_modifications)
    return unless stream_yielder

    new_modifications.each do |m|
      stream_yielder << Riffer::StreamEvents::GuardrailModification.new(m)
    end
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Riffer::Guardrails::Tripwire, Array[Riffer::Guardrails::Modification], ?token_usage: Riffer::Providers::TokenUsage?, ?steps: Integer) -> Riffer::Agent::Response
  def tripwire_response(agent, stream_yielder, tripwire, all_modifications, token_usage: nil, steps: 0)
    stream_yielder << Riffer::StreamEvents::GuardrailTripwire.new(tripwire) if stream_yielder
    build_response(agent, "", tripwire: tripwire, modifications: all_modifications, token_usage: token_usage,
                              steps: steps,)
  end

  #--
  #: (Riffer::Agent, Array[Riffer::Guardrails::Modification], **untyped) -> Riffer::Agent::Response
  def final_response(agent, all_modifications, **extra)
    response = agent.session.final_assistant_message
    build_response(agent, response&.content || "", modifications: all_modifications,
                                                   structured_output: validate_structured_output(agent, response), **extra,)
  end

  #--
  #: (Riffer::Agent, ?Hash[String, String]) -> Riffer::Messages::Assistant
  def call_llm(agent, tags = {})
    agent.provider.generate_text(
      messages: agent.session.messages,
      model: agent.model_name,
      tools: effective_tools(agent),
      **merged_model_options(agent, tags),
    )
  end

  #--
  #: (Riffer::Agent, ?Hash[String, String]) -> Enumerator[Riffer::StreamEvents::Base, void]
  def call_llm_stream(agent, tags = {})
    agent.provider.stream_text(
      messages: agent.session.messages,
      model: agent.model_name,
      tools: effective_tools(agent),
      **merged_model_options(agent, tags),
    )
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, ?tool_calls: Array[Riffer::Messages::Assistant::ToolCall], ?tags: Hash[String, String]) -> void
  def execute_tool_calls(agent, assistant_message, tool_calls: assistant_message.tool_calls, tags: {})
    return if tool_calls.empty?

    results = agent.tool_runtime.execute(tool_calls, tools: effective_tools(agent), context: agent.context,
                                                     assistant_message: assistant_message, tags: tags,)

    inject_discovered_tools(agent, results)

    results.each do |tool_call, result|
      agent.session.add(Riffer::Messages::Tool.new(
                          result.content,
                          tool_call_id: tool_call.call_id,
                          name: tool_call.name,
                          error: result.error_message,
                          error_type: result.error_type,
                        ))
    end
  end

  #--
  #: (Riffer::Agent, Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]) -> void
  def inject_discovered_tools(agent, results)
    to_inject = results.flat_map do |_, result|
      result.is_a?(Riffer::Mcp::SearchTool::Result) ? result.discovered_tools : [] #: Array[singleton(Riffer::Tool)]
    end
    return if to_inject.empty?

    agent.context.discover_tools(to_inject)
  end

  #--
  #: (Riffer::Agent, ?Hash[String, String]) -> void
  def execute_pending_tool_calls(agent, tags = {})
    assistant_message, pending = agent.session.pending_tool_calls
    execute_tool_calls(agent, assistant_message, tool_calls: pending, tags: tags) if assistant_message
  end

  #--
  #: (Riffer::Agent, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], ?Hash[String, String]) { (Riffer::Guardrails::Tripwire) -> void } -> void
  def run_before_guardrails(agent, stream_yielder, all_modifications, tags = {})
    guardrails = agent.config.guardrails_for(:before)
    return if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :before, context: agent.context, tags: tags)
    processed_messages, tripwire, modifications = runner.run(agent.session.messages)
    agent.session.set(processed_messages) unless tripwire
    record_modifications!(stream_yielder, all_modifications, modifications)
    yield tripwire if tripwire
  end

  #--
  #: (Riffer::Agent, Riffer::Messages::Assistant, Enumerator::Yielder?, Array[Riffer::Guardrails::Modification], ?Hash[String, String]) { (Riffer::Guardrails::Tripwire) -> void } -> untyped
  def run_after_guardrails(agent, response, stream_yielder, all_modifications, tags = {})
    guardrails = agent.config.guardrails_for(:after)
    return response if guardrails.empty?

    runner = Riffer::Guardrails::Runner.new(guardrails, phase: :after, context: agent.context, tags: tags)
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

  # +tags+ rides in the options hash as a curated key the providers extract for
  # native request-metadata mapping (alongside +:structured_output+); it never
  # reaches an SDK call verbatim. Span tagging is threaded separately to each
  # builder.
  #--
  #: (Riffer::Agent, ?Hash[String, String]) -> Hash[Symbol, untyped]
  def merged_model_options(agent, tags = {})
    opts = agent.config.model_options.dup
    opts[:structured_output] = agent.structured_output if agent.structured_output
    opts[:tags] = tags unless tags.empty?
    opts
  end

  #--
  #: (Riffer::Agent, String, ?tripwire: Riffer::Guardrails::Tripwire?, ?modifications: Array[Riffer::Guardrails::Modification], ?interrupted: bool, ?interrupt_reason: (String | Symbol)?, ?structured_output: Hash[Symbol, untyped]?, ?healed_tool_call_ids: Array[String], ?token_usage: Riffer::Providers::TokenUsage?, ?steps: Integer) -> Riffer::Agent::Response
  def build_response(agent, content, tripwire: nil, modifications: [], interrupted: false, interrupt_reason: nil,
                     structured_output: nil, healed_tool_call_ids: [], token_usage: nil, steps: 0)
    messages = agent.session.messages
    Riffer::Agent::Response.new(content, tripwire: tripwire, modifications: modifications, interrupted: interrupted,
                                         interrupt_reason: interrupt_reason, structured_output: structured_output, messages: messages.frozen? ? messages : messages.dup.freeze, healed_tool_call_ids: healed_tool_call_ids, token_usage: token_usage, steps: steps,)
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
  #: (Riffer::Agent, ?Hash[String, String]) -> Hash[String, untyped]
  def run_span_attributes(agent, tags = {})
    {
      "gen_ai.operation.name" => "invoke_agent",
      "gen_ai.agent.name" => agent.class.identifier,
      "gen_ai.provider.name" => agent.provider.class.semconv_provider_name,
      "gen_ai.request.model" => agent.model_name,
    }.merge(tag_attributes(tags))
  end

  #--
  #: (Hash[(String | Symbol), untyped]?) -> Hash[String, String]
  def normalize_tags(tags)
    return {} if tags.nil?
    raise Riffer::ArgumentError, "tags: must be a Hash, got #{tags.class}" unless tags.is_a?(Hash)

    result = {} #: Hash[String, String]
    tags.each do |key, value|
      next if value.nil?

      result[key.to_s] = value.to_s
    end
    result
  end

  #--
  #: (Hash[String, String]) -> Hash[String, String]
  def tag_attributes(tags)
    tags.transform_keys { |key| "riffer.tag.#{key}" }
  end

  #--
  #: (Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span, Riffer::Agent::Response) -> void
  def record_run_outcome(span, response)
    span.set_attribute("riffer.steps", response.steps)
    Riffer::Tracing.record_usage(span, response.token_usage)

    span.set_attribute("riffer.interrupt.reason", response.interrupt_reason.to_s) if response.interrupt_reason

    tripwire = response.tripwire
    return unless tripwire

    class_name = tripwire.guardrail.name
    if class_name
      span.set_attribute("riffer.tripwire.guardrail",
                         Riffer::Helpers::ClassNameConverter.convert(class_name),)
    end
    span.set_attribute("riffer.tripwire.reason", tripwire.reason)
    span.set_attribute("riffer.tripwire.phase", tripwire.phase.to_s)
  end
end
