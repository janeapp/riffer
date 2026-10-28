# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: tags" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }

      ACCEPTANCE_MODES.each do |mode|
        it "sends per-call tags the provider's way (#{mode})" do
          prompt = "Reply with the word pong and nothing else."
          message = acceptance_cassette("tags/#{provider_name}/per_call_#{mode}") do
            call_provider(provider, mode, prompt: prompt, model: model)
            call_provider(provider, mode, prompt: prompt, model: model, tags: ACCEPTANCE_TAGS)
          end
          untagged, tagged = acceptance_request_bodies

          expect(tagged).must_equal untagged.merge(acceptance_setting(provider_name, :wire_tags))
          expect(message.content.downcase).must_include "pong"
        end
      end
    end
  end
end
