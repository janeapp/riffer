# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: reasoning" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "reasoning/#{provider_name}" }
      let(:question) { Riffer::Messages::User.new("What is the weather in Toronto?") }

      let(:weather_tool) { acceptance_weather_tool }
      let(:thinking) { acceptance_setting(provider_name, :thinking_options) }
      let(:agent_model) { acceptance_model_id(provider_name) }

      def reasoning_agent(level)
        model_id = agent_model
        Class.new(Riffer::Agent) do
          model model_id
          instructions "Be concise."
          reasoning level
        end.new
      end

      acceptance_setting(provider_name, :reasoning_levels).each do |level|
        it "answers at reasoning level #{level}" do
          response = acceptance_cassette("#{cassette_prefix}/level_#{level}") do
            reasoning_agent(level).generate("What is 17 times 23? Reply with just the number.")
          end

          expect(response.outcome.reason).must_equal :completed
          expect(response.content).must_include "391"
        end
      end

      it "counts thinking tokens as output tokens" do
        level = acceptance_setting(provider_name, :reasoning_levels).last
        response = acceptance_cassette("#{cassette_prefix}/level_#{level}") do
          reasoning_agent(level).generate("What is 17 times 23? Reply with just the number.")
        end

        # The answer is a few tokens; the rest of the output is thinking.
        expect(response.token_usage.output_tokens).must_be :>, 20
      end

      it "streams reasoning before the finish" do
        events = acceptance_cassette("#{cassette_prefix}/replay_stream") do
          provider.stream_text(messages: [question], model: model, tools: [weather_tool], **thinking).to_a
        end
        done = events.grep(Riffer::StreamEvents::ReasoningDone)
        deltas = events.grep(Riffer::StreamEvents::ReasoningDelta)
        finish = events.grep(Riffer::StreamEvents::FinishReasonDone).last

        expect(done).wont_be_empty
        expect(done.all? { |event| event.part.format && (event.part.data || event.part.text) }).must_equal true
        expect(deltas.all? { |delta| events.index(delta) < events.index(done.last) }).must_equal true
        expect(events.index(done.last)).must_be :<, events.index(finish)
      end

      it "streams an answer at a reasoning level" do
        response = acceptance_cassette("#{cassette_prefix}/level_low_stream") do
          run_agent(reasoning_agent(:low), :stream, "What is 17 times 23? Reply with just the number.")
        end

        expect(response.content).must_include "391"
      end

      ACCEPTANCE_MODES.each do |mode|
        it "captures reasoning for a tool call and replays it (#{mode})" do
          first, second = acceptance_cassette("#{cassette_prefix}/replay_#{mode}") do
            first = call_provider(provider, mode, messages: [question], model: model, tools: [weather_tool], **thinking)
            history = [question, first, weather_result(first.tool_calls.first)]
            [first, call_provider(provider, mode, messages: history, model: model, tools: [weather_tool], **thinking)]
          end

          expect(first.reasoning).wont_be_empty
          expect(first.reasoning.all? { |part| part.format && (part.data || part.text) }).must_equal true
          expect(second.content).must_include "15"
        end

        it "leaves out reasoning from another provider (#{mode})" do
          foreign = Riffer::Messages::Assistant::ReasoningPart.new(
            type: :encrypted,
            data: "not-a-valid-signature",
            format: "acceptance-foreign-v1",
          )
          messages = [
            Riffer::Messages::User.new("My name is Ada."),
            Riffer::Messages::Assistant.new("Nice to meet you, Ada!", reasoning: [foreign]),
            Riffer::Messages::User.new("What is my name? Reply with just the name."),
          ]
          message = acceptance_cassette("#{cassette_prefix}/foreign_reasoning_#{mode}") do
            call_provider(provider, mode, messages: messages, model: model)
          end

          expect(message.content).must_include "Ada"
        end

        it "continues a tool call another provider made in the same turn (#{mode})" do
          tool_call = Riffer::Messages::Assistant::ToolCall.new(
            call_id: "toolu_01A",
            name: "get_weather",
            arguments: '{"city":"Toronto"}',
          )
          history = [question, Riffer::Messages::Assistant.new("", tool_calls: [tool_call]), weather_result(tool_call)]
          message = acceptance_cassette("#{cassette_prefix}/foreign_tool_call_#{mode}") do
            call_provider(provider, mode, messages: history, model: model, tools: [weather_tool])
          end

          expect(message.content).must_include "15"
        end
      end
    end
  end
end
