# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: skills" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:cassette_prefix) { "skills/#{provider_name}" }
      let(:prompt) { "Review this Ruby code: def add(a, b) a + b end" }
      let(:agent) do
        model_id = "#{provider_name}/#{acceptance_setting(provider_name, :model)}"
        Class.new(Riffer::Agent) do
          model model_id
          instructions "You are a helpful assistant."
          skills { backend Riffer::Skills::FilesystemBackend.new(SKILLS_FIXTURES_PATH) }
        end.new
      end

      ACCEPTANCE_MODES.each do |mode|
        it "activates a matching skill and answers (#{mode})" do
          response = acceptance_cassette("#{cassette_prefix}/activation_#{mode}") do
            run_agent(agent, mode, prompt)
          end
          activation = response.messages.grep(Riffer::Messages::Tool).first

          expect(activation.name).must_equal agent.context.skills.adapter.skill_activate_tool.name
          expect(agent.context.skills.activated?("code-review")).must_equal true
          expect(response.outcome.reason).must_equal :completed
          expect(response.content).wont_be_empty
        end
      end

      it "streams a SkillActivation event" do
        events, = acceptance_cassette("#{cassette_prefix}/activation_stream") do
          stream_agent(agent, prompt)
        end

        expect(events.grep(Riffer::StreamEvents::SkillActivation).map(&:name)).must_equal ["code-review"]
      end
    end
  end
end
