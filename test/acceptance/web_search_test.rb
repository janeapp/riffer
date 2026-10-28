# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: web search" do
  %i[gemini google_cloud].each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { ACCEPTANCE_MODELS.fetch(provider_name) }
      let(:cassette_prefix) { "web_search/#{provider_name}" }
      let(:prompt) { "What is the latest stable Ruby version? Answer in one sentence." }

      let(:weather_tool) do
        stub_tool("GetWeather") do
          description "Get the current weather for a city"
          params { required :city, String, description: "The city name" }
        end
      end

      ACCEPTANCE_MODES.each do |mode|
        it "answers from the search (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/answer_#{mode}") do
            call_provider(provider, mode, prompt: prompt, model: model, web_search: true)
          end

          expect(message.content).must_include "Ruby"
          expect(message.finish_reason).must_equal :stop
        end

        it "passes web_search options through (#{mode})" do
          options = { timeRangeFilter: { startTime: "2026-01-01T00:00:00Z", endTime: "2026-10-22T00:00:00Z" } }
          message = acceptance_cassette("#{cassette_prefix}/options_#{mode}") do
            call_provider(provider, mode, prompt: prompt, model: model, web_search: options)
          end

          expect(message.content).must_include "Ruby"
        end

        it "searches next to a function tool across a round trip (#{mode})" do
          question = Riffer::Messages::User.new("What is the weather in Toronto, and what is the latest Ruby version?")
          answer = acceptance_cassette("#{cassette_prefix}/with_tool_#{mode}") do
            first = call_provider(
              provider,
              mode,
              messages: [question],
              model: model,
              tools: [weather_tool],
              web_search: true,
            )
            tool_call = first.tool_calls.first
            result = Riffer::Messages::Tool.new(
              "It is 15 degrees Celsius in Toronto.",
              tool_call_id: tool_call.call_id,
              name: tool_call.name,
            )
            call_provider(
              provider,
              mode,
              messages: [question, first, result],
              model: model,
              tools: [weather_tool],
              web_search: true,
            )
          end

          expect(answer.content).must_include "15"
          expect(answer.content).must_include "Ruby"
        end
      end

      it "streams a WebSearchDone with the queries and sources" do
        events = acceptance_cassette("#{cassette_prefix}/answer_stream") do
          provider.stream_text(prompt: prompt, model: model, web_search: true).to_a
        end
        done = events.grep(Riffer::StreamEvents::WebSearchDone)
        statuses = events.grep(Riffer::StreamEvents::WebSearchStatus)

        expect(done).wont_be_empty
        expect(done).must_be(:all?) { |event| !event.query.empty? }
        expect(done.flat_map(&:sources)).wont_be_empty
        expect(done.flat_map(&:sources)).must_be(:all?) { |source| source.keys == %i[title url] && source[:url] }
        expect(statuses).must_be(:all?) { |status| events.index(status) < events.index(done.last) }
      end

      it "keeps the streamed answer in the Agent session" do
        model_id = "#{provider_name}/#{model}"
        agent = Class.new(Riffer::Agent) do
          model model_id
          model_options web_search: true
        end.new

        events, response = acceptance_cassette("#{cassette_prefix}/agent_stream") do
          stream_agent(agent, prompt)
        end
        streamed = events.grep(Riffer::StreamEvents::TextDelta).map(&:content).join

        expect(streamed).must_include "Ruby"
        expect(response.content).must_equal streamed
        expect(agent.session.messages.last.content).must_equal streamed
      end
    end
  end
end
