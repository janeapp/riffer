# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: tags" do
  %i[gemini google_cloud].each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { ACCEPTANCE_MODELS.fetch(provider_name) }

      it "accepts per-call tags" do
        message = acceptance_cassette("tags/#{provider_name}/per_call") do
          provider.generate_text(
            prompt: "Reply with the word pong and nothing else.",
            model: model,
            tags: { "team" => "growth", "agent" => "support/triage_agent", "user_id" => "u_1" },
          )
        end

        expect(message.content.downcase).must_include "pong"
      end
    end
  end
end
