# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: finish reasons" do
  %i[gemini google_cloud].each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { ACCEPTANCE_MODELS.fetch(provider_name) }
      let(:cassette_prefix) { "finish_reasons/#{provider_name}" }
      let(:token_limit) { { ACCEPTANCE_MAX_TOKENS_OPTION.fetch(provider_name) => 20 } }

      let(:note_tool) do
        stub_tool("SaveNote") do
          description "Save a note"
          params { required :body, String, description: "The full note text" }
        end
      end

      ACCEPTANCE_MODES.each do |mode|
        it "finishes with :stop (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/stop_#{mode}") do
            call_provider(provider, mode, prompt: "Reply with the word pong and nothing else.", model: model)
          end

          expect(message.finish_reason).must_equal :stop
          expect(message.finish_reason_raw).wont_be_nil
        end

        it "finishes with :length at the token limit (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/length_#{mode}") do
            call_provider(provider, mode, prompt: "Write a 500-word essay about the sea.", model: model, **token_limit)
          end

          expect(message.finish_reason).must_equal :length
        end

        it "finishes with :length when the limit cuts a tool call off (#{mode})" do
          prompt = "Save a note with the full text of a 300-word story about a lighthouse keeper."
          message = acceptance_cassette("#{cassette_prefix}/length_tool_call_#{mode}") do
            call_provider(provider, mode, prompt: prompt, model: model, tools: [note_tool], **token_limit)
          end

          expect(message.finish_reason).must_equal :length
          message.tool_calls.each { |tool_call| JSON.parse(tool_call.arguments) }
        end
      end

      it "streams one FinishReasonDone after the text" do
        events = acceptance_cassette("#{cassette_prefix}/stop_stream") do
          provider.stream_text(prompt: "Reply with the word pong and nothing else.", model: model).to_a
        end
        done = events.grep(Riffer::StreamEvents::FinishReasonDone)

        expect(done.size).must_equal 1
        expect(events.index(done.first)).must_be :>, events.index(events.grep(Riffer::StreamEvents::TextDone).last)
      end

      it "reports :length as the Agent outcome" do
        model_id = "#{provider_name}/#{model}"
        limit = token_limit
        agent = Class.new(Riffer::Agent) do
          model model_id
          model_options limit
        end.new

        response = acceptance_cassette("#{cassette_prefix}/agent_length") do
          agent.generate("Write a 500-word essay about the sea.")
        end

        expect(response.outcome.reason).must_equal :length
        expect(response.outcome.detail).wont_be_nil
      end
    end
  end
end
