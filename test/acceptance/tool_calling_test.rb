# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: tool calling" do
  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "tool_calling/#{provider_name}" }

      let(:weather_tool) { acceptance_weather_tool }

      let(:time_tool) do
        stub_tool("GetTime") do
          description "Get the current time in UTC"

          def call(context:)
            text("It is 14:05 UTC.")
          end
        end
      end

      let(:booking_tool) do
        stub_tool("BookVisit") do
          description "Book a clinic visit"
          params do
            required :patient, Hash, description: "The patient" do
              required :name, String, description: "Full name"
              optional :email, String, format: "email", description: "Email address, if given"
            end
            required :visit_type, String, enum: %w[in_person online], description: "How the visit happens"
            required :visit_on, String, format: "date", description: "Visit date"
            required :services, Array, description: "Services to book, in the order given" do
              required :name, String, description: "Service name"
              required :minutes, Integer, description: "Length in minutes"
            end
            required :room, Riffer::Params::AnyOf, description: "Room number, or any when there is no preference" do
              variant Integer
              variant String, enum: ["any"]
            end
          end
        end
      end

      let(:weather_results) { ["It is 15 degrees Celsius in Toronto.", "It is 22 degrees Celsius in Paris."] }

      let(:agent_model) { acceptance_model_id(provider_name) }

      def agent_with(tools, steps: nil, session: nil)
        model_id = agent_model
        Class.new(Riffer::Agent) do
          model model_id
          instructions "Use the tools to answer. Be concise."
          uses_tools tools
          max_steps steps if steps
        end.new(session: session)
      end

      ACCEPTANCE_MODES.each do |mode|
        it "calls one tool (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/one_call_#{mode}") do
            call_provider(
              provider,
              mode,
              prompt: "What is the weather in Toronto?",
              model: model,
              tools: [weather_tool],
            )
          end
          tool_call = message.tool_calls.first

          expect(message.tool_calls.size).must_equal 1
          expect(tool_call.name).must_equal "get_weather"
          expect(JSON.parse(tool_call.arguments)).must_equal({ "city" => "Toronto" })
          expect(tool_call.call_id).wont_be_empty
          expect(message.finish_reason).must_equal :tool_calls
        end

        it "calls a tool without arguments (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/no_arguments_#{mode}") do
            call_provider(provider, mode, prompt: "What time is it?", model: model, tools: [time_tool])
          end
          tool_call = message.tool_calls.first

          expect(message.tool_calls.size).must_equal 1
          expect(tool_call.name).must_equal "get_time"
          expect(JSON.parse(tool_call.arguments)).must_equal({})
        end

        it "calls a tool with nested, enum, format and any_of params (#{mode})" do
          prompt = "Book an online visit on 2026-11-03 for Ada Lovelace (ada@example.com): " \
                   "a 30-minute checkup, then a 15-minute vaccination. Any room is fine."
          message = acceptance_cassette("#{cassette_prefix}/nested_params_#{mode}") do
            call_provider(provider, mode, prompt: prompt, model: model, tools: [booking_tool])
          end
          tool_call = message.tool_calls.first
          arguments = booking_tool.params.validate(JSON.parse(tool_call.arguments, symbolize_names: true))

          expect(tool_call.name).must_equal "book_visit"
          expect(arguments[:patient]).must_equal({ name: "Ada Lovelace", email: "ada@example.com" })
          expect(arguments[:visit_type]).must_equal "online"
          expect(arguments[:visit_on]).must_equal "2026-11-03"
          expect(arguments[:services].map { |service| service[:minutes] }).must_equal [30, 15]
          expect(arguments[:room]).must_equal "any"
        end

        it "calls tools in parallel (#{mode})" do
          message = acceptance_cassette("#{cassette_prefix}/parallel_calls_#{mode}") do
            call_provider(
              provider,
              mode,
              prompt: "What is the weather in Toronto and in Paris?",
              model: model,
              tools: [weather_tool],
            )
          end
          cities = message.tool_calls.map { |tool_call| JSON.parse(tool_call.arguments)["city"] }

          expect(cities.sort).must_equal %w[Paris Toronto]
          expect(message.tool_calls.map(&:call_id).uniq.size).must_equal 2
        end

        it "answers from a tool result (#{mode})" do
          question = Riffer::Messages::User.new("What is the weather in Toronto?")
          answer = acceptance_cassette("#{cassette_prefix}/round_trip_#{mode}") do
            first = call_provider(provider, mode, messages: [question], model: model, tools: [weather_tool])
            history = [question, first, weather_result(first.tool_calls.first)]
            call_provider(provider, mode, messages: history, model: model, tools: [weather_tool])
          end

          expect(answer.content).must_include "15"
          expect(answer.finish_reason).must_equal :stop
        end

        it "answers from parallel tool results sent back in one turn (#{mode})" do
          question = Riffer::Messages::User.new("What is the weather in Toronto and in Paris?")
          answer = acceptance_cassette("#{cassette_prefix}/parallel_round_trip_#{mode}") do
            first = call_provider(provider, mode, messages: [question], model: model, tools: [weather_tool])
            history = [question, first, *first.tool_calls.map { |tool_call| weather_result(tool_call) }]
            call_provider(provider, mode, messages: history, model: model, tools: [weather_tool])
          end

          expect(answer.content).must_include "15"
          expect(answer.content).must_include "22"
        end

        it "runs a multi-step tool loop through an Agent (#{mode})" do
          landmark_tool = stub_tool("LocateLandmark") do
            description "Find the city a landmark is in"
            params { required :landmark, String, description: "The landmark name" }

            def call(context:, landmark:)
              text("The #{landmark} is in Paris.")
            end
          end
          agent = agent_with([landmark_tool, weather_tool])

          response = acceptance_cassette("#{cassette_prefix}/agent_loop_#{mode}") do
            run_agent(agent, mode, "First find the city the Eiffel Tower is in, then get the weather there.")
          end
          tool_names = response.messages.grep(Riffer::Messages::Tool).map(&:name)

          expect(response.outcome.reason).must_equal :completed
          expect(tool_names).must_equal %w[locate_landmark get_weather]
          expect(response.content).must_include "22"
        end

        it "continues an Agent session across turns (#{mode})" do
          agent = agent_with([weather_tool])

          response = acceptance_cassette("#{cassette_prefix}/agent_turns_#{mode}") do
            run_agent(agent, mode, "What is the weather in Toronto?")
            run_agent(agent, mode, "And in Paris?")
          end

          expect(response.outcome.reason).must_equal :completed
          expect(agent.session.messages.grep(Riffer::Messages::Tool).map(&:content)).must_equal weather_results
          expect(response.content).must_include "22"
        end

        it "continues a session persisted as JSON in a new Agent (#{mode})" do
          resumed = nil
          response = acceptance_cassette("#{cassette_prefix}/agent_resume_#{mode}") do
            first = agent_with([weather_tool])
            run_agent(first, mode, "What is the weather in Toronto?")
            persisted = JSON.parse(JSON.generate(first.session.messages.map(&:to_h)), symbolize_names: true)
            messages = persisted.map { |hash| Riffer::Messages::Base.from_hash(hash) }
            resumed = agent_with([weather_tool], session: Riffer::Agent::Session.new(messages: messages))
            run_agent(resumed, mode, "And in Paris?")
          end

          expect(response.outcome.reason).must_equal :completed
          expect(resumed.session.messages.grep(Riffer::Messages::Tool).map(&:content)).must_equal weather_results
          expect(response.content).must_include "22"
        end
      end

      it "streams one ToolCallDone per call, before the finish" do
        events = acceptance_cassette("#{cassette_prefix}/parallel_calls_stream") do
          provider.stream_text(
            prompt: "What is the weather in Toronto and in Paris?",
            model: model,
            tools: [weather_tool],
          ).to_a
        end
        done = events.grep(Riffer::StreamEvents::ToolCallDone)
        deltas = events.grep(Riffer::StreamEvents::ToolCallDelta)
        finish = events.grep(Riffer::StreamEvents::FinishReasonDone).last
        deltas_before_done = done.map do |call|
          call_deltas = deltas.select { |delta| delta.item_id == call.item_id }
          call_deltas.all? { |delta| events.index(delta) < events.index(call) }
        end

        expect(done.map(&:name)).must_equal %w[get_weather get_weather]
        expect(done.map(&:call_id).uniq.size).must_equal 2
        expect(deltas_before_done).must_equal [true, true]
        expect(events.index(done.last)).must_be :<, events.index(finish)
      end

      it "streams the Agent's tool calls and final text" do
        agent = agent_with([weather_tool])

        events, response = acceptance_cassette("#{cassette_prefix}/agent_stream_events") do
          stream_agent(agent, "What is the weather in Toronto?")
        end
        tool_done = events.grep(Riffer::StreamEvents::ToolCallDone).first
        text_done = events.grep(Riffer::StreamEvents::TextDone).last

        expect(tool_done.name).must_equal "get_weather"
        expect(events.index(text_done)).must_be :>, events.index(tool_done)
        expect(response.content).must_equal text_done.content
      end

      it "sends a raising tool's error back and still answers" do
        broken_tool = stub_tool("GetForecast") do
          description "Get tomorrow's forecast for a city"
          params { required :city, String, description: "The city name" }

          def call(context:, city:)
            raise Riffer::ToolExecutionError, "The forecast service for #{city} is down"
          end
        end
        agent = agent_with([broken_tool], steps: 4)

        response = acceptance_cassette("#{cassette_prefix}/agent_tool_error") do
          agent.generate("What is tomorrow's forecast for Toronto? If the tool fails, say so.")
        end
        tool_result = response.messages.grep(Riffer::Messages::Tool).first

        expect(tool_result.content).must_include "is down"
        expect(response.outcome.reason).must_equal :completed
        expect(response.content).wont_be_empty
      end

      it "stops at max_steps" do
        agent = agent_with([weather_tool], steps: 1)

        response = acceptance_cassette("#{cassette_prefix}/agent_max_steps") do
          agent.generate("What is the weather in Toronto?")
        end

        expect(response.outcome.reason).must_equal :max_steps
        expect(response.steps).must_equal 1
      end
    end
  end
end
