# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: errors" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "errors/#{provider_name}" }
      let(:error_contract) { acceptance_setting(provider_name, :error_contract) }

      def api_error(scenario, mode, **options)
        acceptance_cassette("#{cassette_prefix}/#{scenario}_#{mode}") do
          expect { call_provider(provider, mode, prompt: "Say hello", **options) }.must_raise error_contract[:class]
        end
      end

      def status(error) = error_contract[:status].call(error)

      def detail(error) = error_contract[:detail].call(error)

      ACCEPTANCE_MODES.each do |mode|
        it "raises the provider's API error for invalid credentials (#{mode})" do
          break_acceptance_credentials(provider_name)

          error = api_error("invalid_credentials", mode, model: model)

          expect(400..403).must_include status(error)
          expect(detail(error)).wont_be_empty
        end

        it "raises the provider's API error for an unknown model (#{mode})" do
          error = api_error("unknown_model", mode, model: "riffer-unknown-model")

          expect(400..404).must_include status(error)
          expect(detail(error)).wont_be_empty
        end

        it "raises the provider's API error for an invalid option (#{mode})" do
          error = api_error("invalid_option", mode, model: model, **acceptance_setting(provider_name, :invalid_options))

          expect(status(error)).must_equal 400
        end
      end
    end
  end
end
