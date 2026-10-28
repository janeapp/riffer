# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: usage" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before do
        configure_acceptance_provider(provider_name)
        Riffer.config.catalog_files = [ACCEPTANCE_CATALOG_PATH]
      end

      after do
        reset_acceptance_provider(provider_name)
        Riffer.config.catalog_files = []
      end

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "usage/#{provider_name}" }

      # The catalog's prices per million tokens, applied by hand so the check
      # doesn't reuse riffer's own formula.
      def expected_cost(usage)
        rates = Riffer.config.catalog.rates_for(catalog_key)
        cached = usage.cache_read_tokens.to_i
        uncached = (usage.input_tokens - cached) * rates.input
        (uncached + (cached * rates.cache_read) + (usage.output_tokens * rates.output)) / 1_000_000
      end

      let(:catalog_key) { acceptance_model_id(provider_name) }

      ACCEPTANCE_MODES.each do |mode|
        it "reports input and output tokens (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/tokens_#{mode}") do
            call_provider(provider, mode, prompt: "Count from 1 to 40, separated by commas.", model: model)
          end

          expect(message.token_usage.input_tokens).must_be :>, 0
          expect(message.token_usage.output_tokens).must_be :>, 0
          expect(message.token_usage.cost).must_be_within_delta expected_cost(message.token_usage), 1e-12
        end

        it "reports cached input tokens on a repeated prompt (#{mode})" do
          rules = (1..400).map { |n| "Rule #{n}: staff member #{n} opens the clinic on day #{n % 7}." }.join("\n")
          system = "You answer questions about this handbook.\n\n#{rules}"
          messages = acceptance_cassette("#{cassette_prefix}/cache_#{mode}") do
            Array.new(2) do
              call_provider(provider, mode, system: system, prompt: "Who opens on day 3? Name one.", model: model)
            end
          end

          # Implicit caching is best-effort: a warm cache can hit on the first call.
          cached = messages.max_by { |message| message.token_usage.cache_read_tokens.to_i }.token_usage

          expect(cached.cache_read_tokens.to_i).must_be :>, 0
          expect(cached.cost).must_be_within_delta expected_cost(cached), 1e-12
        end
      end

      it "streams one TokenUsageDone for the response" do
        events = acceptance_cassette("#{cassette_prefix}/tokens_stream") do
          provider.stream_text(prompt: "Count from 1 to 40, separated by commas.", model: model).to_a
        end

        expect(events.grep(Riffer::StreamEvents::TokenUsageDone).size).must_equal 1
      end

      it "adds up usage across an Agent run" do
        weather_tool = acceptance_weather_tool
        agent = Class.new(Riffer::Agent) do
          model acceptance_model_id(provider_name)
          uses_tools [weather_tool]
        end.new

        response = acceptance_cassette("#{cassette_prefix}/agent") do
          agent.generate("What is the weather in Toronto?")
        end
        per_step = response.messages.grep(Riffer::Messages::Assistant).map(&:token_usage)

        expect(response.steps).must_equal per_step.size
        expect(response.token_usage.input_tokens).must_equal per_step.sum(&:input_tokens)
        expect(response.token_usage.output_tokens).must_equal per_step.sum(&:output_tokens)
        expect(response.token_usage.cost).must_be_within_delta per_step.sum(&:cost), 1e-12
      end
    end
  end
end
