# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: errors" do
  %i[gemini google_cloud].each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { ACCEPTANCE_MODELS.fetch(provider_name) }
      let(:cassette_prefix) { "errors/#{provider_name}" }

      def api_error(scenario, mode, **options)
        acceptance_cassette("#{cassette_prefix}/#{scenario}_#{mode}") do
          expect { call_provider(provider, mode, prompt: "Say hello", **options) }.must_raise Riffer::APIError
        end
      end

      ACCEPTANCE_MODES.each do |mode|
        it "raises an APIError for invalid credentials (#{mode})" do
          configure_invalid_acceptance_credentials(provider_name)

          error = api_error("invalid_credentials", mode, model: model)

          expect(400..403).must_include error.status
          expect(error.body).wont_be_empty
        end

        it "raises an APIError for an unknown model (#{mode})" do
          error = api_error("unknown_model", mode, model: "gemini-0-does-not-exist")

          expect(error.status).must_equal 404
          expect(error.message).must_include "404"
        end

        it "raises an APIError for an invalid option (#{mode})" do
          error = api_error("invalid_option", mode, model: model, temperature: 5)

          expect(error.status).must_equal 400
        end
      end
    end
  end
end
