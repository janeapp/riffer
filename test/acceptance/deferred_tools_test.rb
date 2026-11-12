# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: deferred tools" do
  no_native_loading = "Loads deferred tools through the gateway fallback (#554); no cassettes recorded yet"

  acceptance_providers(
    except: {
      gemini: no_native_loading,
      google_cloud: no_native_loading,
      amazon_bedrock: no_native_loading,
    },
  ).each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:cassette_prefix) { "deferred_tools/#{provider_name}" }
      let(:agent_model) { acceptance_model_id(provider_name) }
      let(:cache_options) { acceptance_setting(provider_name, :cache_options) }

      let(:list_events) do
        stub_tool("ListEvents") do
          identifier "calendar/list_events"
          description "List the user's calendar events on a date"
          params { required :date, :string, description: "The date, as YYYY-MM-DD" }

          def call(context:, date:)
            text("On #{date}: dentist at 09:00, team lunch at 12:30.")
          end
        end
      end

      let(:send_invoice) do
        stub_tool("SendInvoice") do
          description "Send an invoice to a customer"
          params { required :customer, :string, description: "The customer name" }
        end
      end

      let(:find_tools) do
        loads = list_events
        stub_tool("FindTools") do
          description "Find more tools for a task. Describe what you need to do in a few words."
          params { required :query, :string, description: "What you need to do" }

          define_method(:call) { |context:, query:| load_tools([loads]) }
        end
      end

      def agent_with(instructions:, options: {}, session: nil)
        model_id = agent_model
        loader = find_tools
        deferred = [list_events, send_invoice]
        Class.new(Riffer::Agent) do
          model model_id
          instructions instructions
          model_options options
          uses_tools [loader]
          deferred_tools deferred
        end.new(session: session)
      end

      ACCEPTANCE_MODES.each do |mode|
        it "loads a tool and then calls it by its real name (#{mode})" do
          agent = agent_with(instructions: "If you need a tool you don't have, use find_tools. Be concise.")

          response = acceptance_cassette("#{cassette_prefix}/load_and_call_#{mode}") do
            run_agent(agent, mode, "What's on my calendar on 2026-11-06?")
          end
          tool_messages = response.messages.grep(Riffer::Messages::Tool)
          tool_arrays = acceptance_request_bodies.map { |body| JSON.generate(body.fetch("tools")) }

          expect(response.outcome.reason).must_equal :completed
          expect(tool_messages.map(&:name)).must_equal %w[find_tools calendar/list_events]
          expect(tool_messages.first.loaded_tools).must_equal ["calendar/list_events"]
          expect(response.content).must_match(/dentist/i)
          expect(tool_arrays.size).must_equal 3
          expect(tool_arrays.uniq.size).must_equal 1
        end

        it "calls a loaded tool again in an agent restored from JSON (#{mode})" do
          instructions = "If you need a tool you don't have, use find_tools. Be concise."
          resumed = nil
          response = acceptance_cassette("#{cassette_prefix}/resume_#{mode}") do
            first = agent_with(instructions: instructions)
            run_agent(first, mode, "What's on my calendar on 2026-11-06?")
            persisted = JSON.parse(JSON.generate(first.session.messages.map(&:to_h)), symbolize_names: true)
            messages = persisted.map { |hash| Riffer::Messages::Base.from_hash(hash) }
            resumed = agent_with(instructions: instructions, session: Riffer::Agent::Session.new(messages: messages))
            run_agent(resumed, mode, "And on 2026-11-07?")
          end
          later_calls = resumed.session.messages.grep(Riffer::Messages::Tool).drop(2)

          expect(response.outcome.reason).must_equal :completed
          expect(later_calls.filter_map(&:error_type)).must_be_empty
          expect(later_calls.last.name).must_equal "calendar/list_events"
          expect(response.content).must_match(/dentist/i)
        end
      end

      it "reads the prompt cache on the turn after a load" do
        rules = (1..400).map { |n| "Rule #{n}: product PX-#{n} ships in box size #{n % 7}." }.join("\n")
        agent = agent_with(
          instructions: "#{rules}\n\nIf you need a tool you don't have, use find_tools. Be concise.",
          options: cache_options,
        )

        response = acceptance_cassette("#{cassette_prefix}/cache_after_load") do
          agent.generate("What's on my calendar on 2026-11-06?")
        end
        after_load = response.messages.grep(Riffer::Messages::Assistant)[1]

        expect(after_load.tool_calls.map(&:name)).must_equal ["calendar/list_events"]
        expect(after_load.token_usage.cache_read_tokens.to_i).must_be :>, 0
      end
    end
  end
end
