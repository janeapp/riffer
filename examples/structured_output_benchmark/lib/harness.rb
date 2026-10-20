# frozen_string_literal: true

require "json"

# Runs one scenario the way Riffer::Agent's tool loop does — same provider
# request building, same prompted-schema injection, same parse_and_validate —
# but over stream_text, because Agent refuses to stream with structured output
# and TTFT is only observable on a stream.
module Harness
  MAX_STEPS = 24
  MAX_TOKENS = 32_000

  FIRST_TOKEN_EVENTS = [
    Riffer::StreamEvents::TextDelta, Riffer::StreamEvents::ReasoningDelta, Riffer::StreamEvents::ToolCallDelta,
  ].freeze

  module_function

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # provider_factory: -> Riffer::Providers::Base, a fresh one per run (providers hold per-call state).
  def run(scenario:, model:, strategy:, provider_factory:)
    started = now
    steps = []
    structured_output = Riffer::Agent::StructuredOutput.new(scenario.schema, strategy: strategy)
    messages = [Riffer::Messages::System.new(Scenarios::SYSTEM), Riffer::Messages::User.new(scenario.prompt)]
    provider = provider_factory.call
    final = nil

    MAX_STEPS.times do
      step = stream_step(provider, model, messages, structured_output)
      steps << step.except(:message)
      messages << step[:message]
      final = step
      break if step[:message].tool_calls.empty?

      messages.concat(step[:message].tool_calls.map { |call| dispatch(call) })
    end

    finish(scenario, strategy, structured_output, steps, final, now - started,
           max_steps_hit: !final[:message].tool_calls.empty?, messages: messages,)
  rescue StandardError => e
    service_error = e.class.name.start_with?("Aws::", "Seahorse::") || e.is_a?(Riffer::Error)
    { status: service_error ? "api_error" : "harness_error", error: "#{e.class}: #{e.message}"[0, 600],
      backtrace: service_error ? nil : e.backtrace&.first(5), total_s: now - started, steps: steps&.size || 0,
      ttft_s: steps&.first&.dig(:ttft_s), tool_calls: (steps || []).flat_map { |s| s[:tool_calls] }, }
  end

  def stream_step(provider, model, messages, structured_output)
    started = now
    first_token = nil
    first_text = nil
    text = +""
    tool_calls = []
    reasoning = []
    usage = nil
    finish_reason = nil

    provider.stream_text(
      messages: messages, model: model, tools: ClinicTools::ALL, structured_output: structured_output,
      inference_config: { max_tokens: MAX_TOKENS },
    ).each do |event|
      first_token ||= now if FIRST_TOKEN_EVENTS.any? { |klass| event.is_a?(klass) }
      case event
      when Riffer::StreamEvents::TextDelta
        first_text ||= now
        text << event.content
      when Riffer::StreamEvents::ToolCallDone
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(call_id: event.call_id, name: event.name,
                                                                arguments: event.arguments,)
      when Riffer::StreamEvents::ReasoningDone then reasoning << event.part
      when Riffer::StreamEvents::TokenUsageDone then usage = event.token_usage
      when Riffer::StreamEvents::FinishReasonDone then finish_reason = event.finish_reason
      end
    end

    {
      message: Riffer::Messages::Assistant.new(text, tool_calls: tool_calls, reasoning: reasoning,
                                                     finish_reason: finish_reason,),
      ttft_s: first_token && (first_token - started),
      first_text_s: first_text && (first_text - started),
      duration_s: now - started,
      tool_calls: tool_calls.map(&:name),
      finish_reason: finish_reason,
      input_tokens: usage&.input_tokens,
      output_tokens: usage&.output_tokens,
      text_chars: text.size,
    }
  end

  def dispatch(call)
    tool = ClinicTools::ALL.find { |t| t.name == call.name }
    response =
      if tool.nil? then Riffer::Tools::Response.error("Unknown tool '#{call.name}'", type: :unknown_tool)
      else
        args = call.arguments.empty? ? {} : JSON.parse(call.arguments, symbolize_names: true)
        tool.new.call_with_validation(context: nil, **args)
      end
    Riffer::Messages::Tool.new(response.content, tool_call_id: call.call_id, name: call.name,
                                                 error: response.error_message, error_type: response.error_type,)
  rescue JSON::ParserError => e
    Riffer::Messages::Tool.new("Invalid JSON arguments: #{e.message}", tool_call_id: call.call_id, name: call.name,
                                                                       error: e.message, error_type: :validation_error,)
  end

  def finish(scenario, _strategy, structured_output, steps, final, total, max_steps_hit:, messages:)
    content = final[:message].content
    tool_calls = steps.flat_map { |s| s[:tool_calls] }
    tool_errors = messages.count { |m| m.is_a?(Riffer::Messages::Tool) && m.error? }
    result = structured_output.parse_and_validate(content)

    status =
      if max_steps_hit then "max_steps"
      elsif final[:finish_reason] == :length then "truncated"
      elsif result.failure? && result.error.start_with?("JSON parse") then "invalid_json"
      elsif result.failure? then "schema_violation"
      else "ok"
      end

    grade = status == "ok" ? Grading.summarize(scenario.grader.call(result.object)) : nil
    # A schema-invalid reply is still graded, so an abstention that broke the
    # schema can be told apart from an invented value.
    unvalidated = Riffer::Agent::StructuredOutput::Parser.parse(content) if status == "schema_violation"
    record = {
      grade_unvalidated: unvalidated && Grading.summarize(scenario.grader.call(unvalidated)),
      content: content,
      status: status,
      error: result.error,
      total_s: total,
      ttft_s: steps.first[:ttft_s],
      final_step_first_text_s: final[:first_text_s],
      steps: steps.size,
      tool_calls: tool_calls,
      tool_errors: tool_errors,
      input_tokens: steps.sum { |s| s[:input_tokens].to_i },
      output_tokens: steps.sum { |s| s[:output_tokens].to_i },
      raw_json_clean: clean_json?(content),
      prose_chars: content.size - (result.json&.size || content.size),
      step_detail: steps,
      grade: grade,
      output_preview: content[0, 400],
    }
    record.merge(tool_behaviour(scenario, tool_calls))
  end

  def clean_json?(content)
    JSON.parse(content).is_a?(Hash)
  rescue JSON::ParserError
    false
  end

  def tool_behaviour(scenario, tool_calls)
    called = tool_calls.uniq
    case scenario.tools
    when :forbidden
      { unnecessary_tool_use: !tool_calls.empty?, skipped_tools: false, missing_required_tools: [] }
    when :required
      missing = scenario.required_tools - called
      { unnecessary_tool_use: false, skipped_tools: tool_calls.empty?, missing_required_tools: missing }
    end
  end
end
