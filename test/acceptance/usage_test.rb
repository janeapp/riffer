# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: usage" do
  %i[gemini google_cloud].each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { ACCEPTANCE_MODELS.fetch(provider_name) }
      let(:cassette_prefix) { "usage/#{provider_name}" }

      ACCEPTANCE_MODES.each do |mode|
        it "reports input and output tokens (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/tokens_#{mode}") do
            call_provider(provider, mode, prompt: "Count from 1 to 40, separated by commas.", model: model)
          end

          expect(message.token_usage.input_tokens).must_be :>, 0
          expect(message.token_usage.output_tokens).must_be :>, 0
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
          expect(messages.map { |message| message.token_usage.cache_read_tokens.to_i }.max).must_be :>, 0
        end
      end

      it "streams one TokenUsageDone for the response" do
        events = acceptance_cassette("#{cassette_prefix}/tokens_stream") do
          provider.stream_text(prompt: "Count from 1 to 40, separated by commas.", model: model).to_a
        end

        expect(events.grep(Riffer::StreamEvents::TokenUsageDone).size).must_equal 1
      end

      it "adds up usage across an Agent run" do
        weather_tool = stub_tool("GetWeather") do
          description "Get the current weather for a city"
          params { required :city, String, description: "The city name" }

          def call(context:, city:)
            text("It is 15 degrees Celsius in #{city}.")
          end
        end
        model_id = "#{provider_name}/#{model}"
        agent = Class.new(Riffer::Agent) do
          model model_id
          uses_tools [weather_tool]
        end.new

        response = acceptance_cassette("#{cassette_prefix}/agent") do
          agent.generate("What is the weather in Toronto?")
        end
        per_step = response.messages.grep(Riffer::Messages::Assistant).map(&:token_usage)

        expect(response.steps).must_equal per_step.size
        expect(response.token_usage.input_tokens).must_equal per_step.sum(&:input_tokens)
        expect(response.token_usage.output_tokens).must_equal per_step.sum(&:output_tokens)
      end
    end
  end
end
