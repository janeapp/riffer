# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: text" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }

      ACCEPTANCE_MODES.each do |mode|
        it "answers a prompt (#{mode})" do
          message = acceptance_cassette("text/#{provider_name}/prompt_#{mode}") do
            call_provider(provider, mode, prompt: "Reply with the word pong and nothing else.", model: model)
          end

          expect(message.content.downcase).must_include "pong"
          expect(message.finish_reason).must_equal :stop
        end

        it "follows a system prompt (#{mode})" do
          message = acceptance_cassette("text/#{provider_name}/system_#{mode}") do
            call_provider(
              provider,
              mode,
              system: "Always answer in French, in one short sentence.",
              prompt: "Say good morning.",
              model: model,
            )
          end

          expect(message.content).must_match(/bonjour/i)
        end

        it "continues a conversation of message objects (#{mode})" do
          messages = [
            Riffer::Messages::System.new("Be concise."),
            Riffer::Messages::User.new("My name is Ada."),
            Riffer::Messages::Assistant.new("Nice to meet you, Ada!"),
            Riffer::Messages::User.new("What is my name? Reply with just the name."),
          ]
          message = acceptance_cassette("text/#{provider_name}/message_objects_#{mode}") do
            call_provider(provider, mode, messages: messages, model: model)
          end

          expect(message.content).must_include "Ada"
        end

        it "continues a conversation of message hashes (#{mode})" do
          messages = [
            { role: "system", content: "Be concise." },
            { role: "user", content: "My name is Ada." },
            { role: "assistant", content: "Nice to meet you, Ada!" },
            { role: "user", content: "What is my name? Reply with just the name." },
          ]
          message = acceptance_cassette("text/#{provider_name}/message_hashes_#{mode}") do
            call_provider(provider, mode, messages: messages, model: model)
          end

          expect(message.content).must_include "Ada"
        end

        it "keeps multibyte characters intact (#{mode})" do
          message = acceptance_cassette("text/#{provider_name}/multibyte_#{mode}") do
            call_provider(
              provider,
              mode,
              prompt: "Repeat this exactly, with nothing else: ¿Qué tal? 日本語のテキスト 🚀🎉 Ünïcödé",
              model: model,
            )
          end

          expect(message.content).must_include "日本語のテキスト"
          expect(message.content).must_include "🚀🎉"
          expect(message.content).must_include "Ünïcödé"
        end
      end

      it "streams deltas that add up to the final text" do
        events = acceptance_cassette("text/#{provider_name}/prompt_stream") do
          provider.stream_text(prompt: "Reply with the word pong and nothing else.", model: model).to_a
        end
        deltas = events.grep(Riffer::StreamEvents::TextDelta)
        done = events.grep(Riffer::StreamEvents::TextDone)

        expect(deltas).wont_be_empty
        expect(done.size).must_equal 1
        expect(deltas.map(&:content).join).must_equal done.first.content
        expect(events.index(done.first)).must_be :>, events.index(deltas.last)
      end

      it "answers through an Agent" do
        agent = Class.new(Riffer::Agent) do
          model "#{provider_name}/#{acceptance_setting(provider_name, :model)}"
          instructions "Be concise."
        end.new

        response = acceptance_cassette("text/#{provider_name}/agent_generate") do
          agent.generate("Reply with the word pong and nothing else.")
        end

        expect(response.outcome.reason).must_equal :completed
        expect(response.content.downcase).must_include "pong"
      end
    end
  end
end
