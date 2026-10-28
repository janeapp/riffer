# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: web search" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "web_search/#{provider_name}" }
      let(:prompt) { "What is the latest stable Ruby version? Answer in one sentence." }

      let(:weather_tool) { acceptance_weather_tool }

      ACCEPTANCE_MODES.each do |mode|
        it "answers from the search (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/answer_#{mode}") do
            call_provider(provider, mode, prompt: prompt, model: model, web_search: true)
          end

          expect(message.content).must_include "Ruby"
          expect(message.finish_reason).must_equal :stop
        end

        it "passes web_search options through (#{mode})" do
          options = acceptance_setting(provider_name, :web_search_options)
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
            call_provider(
              provider,
              mode,
              messages: [question, first, weather_result(first.tool_calls.first)],
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
        sources = done.flat_map(&:sources)

        expect(done).wont_be_empty
        expect(done.map(&:query)).wont_include ""
        expect(sources).wont_be_empty
        expect(sources.map(&:keys).uniq).must_equal [%i[title url]]
        expect(sources.map { |source| source[:url] }).wont_include nil
        expect(statuses.all? { |status| events.index(status) < events.index(done.last) }).must_equal true
      end

      it "keeps the streamed answer in the Agent session" do
        agent = Class.new(Riffer::Agent) do
          model acceptance_model_id(provider_name)
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
