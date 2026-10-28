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

      let(:weather_tool) do
        stub_tool("GetWeather") do
          description "Get the current weather for a city"
          params { required :city, String, description: "The city name" }
        end
      end

      def weather_result(tool_call)
        Riffer::Messages::Tool.new(
          "It is 15 degrees Celsius in Toronto.",
          tool_call_id: tool_call.call_id,
          name: tool_call.name,
        )
      end

      let(:agent_model) { "#{provider_name}/#{model}" }

      def reasoning_agent(level)
        model_id = agent_model
        Class.new(Riffer::Agent) do
          model model_id
          instructions "Be concise."
          reasoning level
        end.new
      end

      describe "with the test catalog" do
        before { Riffer.config.catalog_files = [ACCEPTANCE_CATALOG_PATH] }
        after { Riffer.config.catalog_files = [] }

        # The catalog maps only the levels a model's provider default can't
        # serve, so the other levels exercise the default.
        Riffer::Agent::Config::REASONING_LEVELS.each do |level|
          it "answers at reasoning level #{level}" do
            response = acceptance_cassette("#{cassette_prefix}/level_#{level}") do
              reasoning_agent(level).generate("What is 17 times 23? Reply with just the number.")
            end

            expect(response.outcome.reason).must_equal :completed
            expect(response.content).must_include "391"
          end
        end
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
            first = call_provider(provider, mode, messages: [question], model: model, tools: [weather_tool])
            history = [question, first, weather_result(first.tool_calls.first)]
            [first, call_provider(provider, mode, messages: history, model: model, tools: [weather_tool])]
          end

          expect(first.reasoning).wont_be_empty
          expect(first.reasoning).must_be(:all?) { |part| part.format && (part.data || part.text) }
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
