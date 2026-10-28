# frozen_string_literal: true

require "acceptance/acceptance_helper"

describe "Acceptance: structured output" do
  strategies = %i[native prompted]

  acceptance_providers.each do |provider_name|
    describe provider_name do
      before { configure_acceptance_provider(provider_name) }
      after { reset_acceptance_provider(provider_name) }

      let(:provider) { Riffer::Providers::Repository.find(provider_name).new }
      let(:model) { acceptance_setting(provider_name, :model) }
      let(:cassette_prefix) { "structured_output/#{provider_name}" }

      # Each scenario's let(:params) and let(:prompt) feed this.
      def structured_result(scenario, strategy, mode)
        structured_output = Riffer::Agent::StructuredOutput.new(params, strategy: strategy)
        message = acceptance_cassette("#{cassette_prefix}/#{scenario}/#{strategy}_#{mode}") do
          call_provider(provider, mode, prompt: prompt, model: model, structured_output: structured_output)
        end
        result = structured_output.parse_and_validate(message.content)

        expect(result.error).must_be_nil
        result.object
      end

      describe "a flat object" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:sentiment, String, enum: %w[positive neutral negative], description: "The sentiment")
            params.required(:score, Float, description: "Confidence between 0 and 1")
          end
        end
        let(:prompt) { "Analyze the sentiment of: 'I love this product, it is amazing!'" }

        strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
          it "returns the object (#{strategy}, #{mode})" do
            object = structured_result("flat", strategy, mode)

            expect(object[:sentiment]).must_equal "positive"
            expect(object[:score]).must_be_kind_of Float
          end
        end

        strategies.each do |strategy|
          it "sets structured_output on the generated message (#{strategy})" do
            structured_output = Riffer::Agent::StructuredOutput.new(params, strategy: strategy)
            message = acceptance_cassette("#{cassette_prefix}/flat/#{strategy}_generate") do
              provider.generate_text(prompt: prompt, model: model, structured_output: structured_output)
            end

            expect(message.structured_output).must_equal structured_output.parse_and_validate(message.content).object
          end
        end
      end

      describe "an address" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:name, String, description: "Person name")
            params.required(:address, Hash, description: "Mailing address") do
              required :street, String, description: "Street address"
              required :city, String, description: "City"
              optional :postal_code, String, description: "Postal or zip code"
              optional :country, String, description: "Country"
            end
          end
        end

        describe "with every field" do
          let(:prompt) { "Extract the address from: John lives at 123 Main St, Toronto, ON M5V 2T6, Canada" }

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns the nested object (#{strategy}, #{mode})" do
              object = structured_result("nested_object", strategy, mode)

              expect(object[:name]).must_include "John"
              expect(object[:address][:street]).must_include "123 Main"
              expect(object[:address][:city]).must_equal "Toronto"
            end
          end
        end

        describe "with optional fields that have no value" do
          let(:prompt) do
            "Extract info from: Jane works at 42 King St in Vancouver. No other details are known. " \
              "Return null for any unknown fields."
          end

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "leaves them nil (#{strategy}, #{mode})" do
              object = structured_result("null_optionals", strategy, mode)

              expect(object[:address][:city]).must_equal "Vancouver"
              expect(object[:address][:postal_code]).must_be_nil
              expect(object[:address][:country]).must_be_nil
            end
          end
        end
      end

      describe "an optional enum" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:name, String, description: "Session name")
            params.optional(:session_type, String, enum: %w[in_person online both], description: "Type of session")
          end
        end

        describe "with a matching value" do
          let(:prompt) { "Classify the session: yoga class, in-person format." }

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns the value (#{strategy}, #{mode})" do
              object = structured_result("optional_enum_present", strategy, mode)

              expect(object[:session_type]).must_equal "in_person"
            end
          end
        end

        describe "without a matching value" do
          let(:prompt) do
            "Classify the session: yoga class, underwater format. The session_type enum does not cover this, " \
              "so return null for session_type."
          end

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns nil (#{strategy}, #{mode})" do
              object = structured_result("optional_enum_absent", strategy, mode)

              expect(object[:session_type]).must_be_nil
            end
          end
        end
      end

      describe "typed arrays" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:tags, Array, of: String, description: "Descriptive tags")
            params.required(:scores, Array, of: Float, description: "Relevance scores between 0 and 1")
          end
        end
        let(:prompt) { "List 3 tags and 3 scores (0.0-1.0) for: 'Ruby is a great programming language'" }

        strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
          it "returns arrays of the item type (#{strategy}, #{mode})" do
            object = structured_result("typed_array", strategy, mode)

            expect(object[:tags].size).must_equal 3
            expect(object[:scores].size).must_equal 3
            expect(object[:tags]).must_be(:all?, String)
            expect(object[:scores]).must_be(:all?, Float)
          end
        end
      end

      describe "an array of objects" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:order_id, String, description: "Order identifier")
            params.required(:items, Array, description: "Line items") do
              required :name, String, description: "Product name"
              required :price, Float, description: "Price in dollars"
              optional :quantity, Integer, description: "Quantity ordered"
            end
          end
        end
        let(:prompt) { "Order A-17 has 2 items: a book costing $12.99 and a pen costing $1.50" }

        strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
          it "returns every object (#{strategy}, #{mode})" do
            object = structured_result("array_of_objects", strategy, mode)

            expect(object[:items].map { |item| item[:price] }).must_equal [12.99, 1.5]
          end
        end
      end

      describe "an any_of of objects" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:result, Riffer::Params::AnyOf, description: "The address, or why none was found") do
              variant do
                required :street, String, description: "Street address"
                required :city, String, description: "City"
              end
              variant do
                required :error_code, String, enum: %w[no_address multiple_addresses], description: "Why no address"
                required :error_message, String, description: "Explanation of the error"
              end
            end
          end
        end

        describe "when the first variant applies" do
          let(:prompt) { "Extract the address from: John lives at 123 Main St, Toronto" }

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns the first variant (#{strategy}, #{mode})" do
              object = structured_result("any_of_first", strategy, mode)

              expect(object[:result][:city]).must_equal "Toronto"
            end
          end
        end

        describe "when only the second variant applies" do
          let(:prompt) { "Extract the address from: John likes long walks by the lake" }

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns the second variant (#{strategy}, #{mode})" do
              object = structured_result("any_of_second", strategy, mode)

              expect(object[:result][:error_code]).must_equal "no_address"
            end
          end
        end
      end

      describe "an any_of of primitives" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            description = "A count, or a word when there is no count"
            params.required(:quantity, Riffer::Params::AnyOf, description: description) do
              variant Integer
              variant String
            end
            params.optional(:due, Riffer::Params::AnyOf, description: "The due date, or none when there isn't one") do
              variant String, format: "date"
              variant String, enum: ["none"]
            end
          end
        end

        describe "when the order has a count and a date" do
          let(:prompt) { "Read this order: 12 boxes, due on 2026-11-03" }

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns the integer and date variants (#{strategy}, #{mode})" do
              object = structured_result("primitive_any_of_first", strategy, mode)

              expect(object).must_equal({ quantity: 12, due: "2026-11-03" })
            end
          end
        end

        describe "when the order has neither" do
          let(:prompt) { "Read this order: several boxes, with no due date" }

          strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
            it "returns the string and enum variants (#{strategy}, #{mode})" do
              object = structured_result("primitive_any_of_second", strategy, mode)

              expect(object[:quantity]).must_be_kind_of String
              expect(object[:due]).must_equal "none"
            end
          end
        end
      end

      describe "an enum array" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:tags, Array, of: String, enum: %w[urgent billing technical account], description: "Tags")
          end
        end
        let(:prompt) { "Tag this support ticket: 'I was charged twice this month and need it fixed today.'" }

        strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
          it "returns values from the enum (#{strategy}, #{mode})" do
            object = structured_result("enum_array", strategy, mode)

            expect(object[:tags]).must_include "billing"
          end
        end
      end

      describe "string formats" do
        let(:clinic_id) { "550e8400-e29b-41d4-a716-446655440000" }
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:visit_on, String, format: "date", description: "Visit date")
            params.required(:starts_at, String, format: "date-time", description: "Visit start, with its UTC offset")
            params.optional(:email, String, format: "email", description: "Patient email, if given")
            params.required(:clinic_ids, Array, of: String, format: "uuid", description: "Clinic IDs")
          end
        end
        let(:prompt) do
          "Book a visit on 2026-10-26 at 9:30am Toronto time (UTC-04:00) at clinic #{clinic_id}. " \
            "The patient gave no email."
        end

        strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
          it "returns values in the format (#{strategy}, #{mode})" do
            object = structured_result("format", strategy, mode)

            expect(object[:visit_on]).must_equal "2026-10-26"
            expect(object[:starts_at]).must_equal "2026-10-26T09:30:00-04:00"
            expect(object[:email]).must_be_nil
            expect(object[:clinic_ids]).must_equal [clinic_id]
          end
        end
      end

      describe "arrays of arrays" do
        let(:params) do
          Riffer::Params.new.tap do |params|
            params.required(:rows, Array, of: [Integer], description: "Seat numbers, one array per row")
            params.optional(:boards, Array, of: [[String]], enum: %w[x o], description: "Tic-tac-toe boards")
          end
        end
        let(:prompt) do
          "Row 1 has seats 1, 2 and 3. Row 2 has seats 4 and 5. " \
            "Game 1's tic-tac-toe board rows are: x o x, o x o, o x x. " \
            "Game 2's rows are: o o x, x x o, o x x."
        end

        strategies.product(ACCEPTANCE_MODES).each do |strategy, mode|
          it "returns the nested arrays (#{strategy}, #{mode})" do
            object = structured_result("array_of_arrays", strategy, mode)

            expect(object[:rows]).must_equal [[1, 2, 3], [4, 5]]
            expect(object[:boards]).must_equal [
              [%w[x o x], %w[o x o], %w[o x x]],
              [%w[o o x], %w[x x o], %w[o x x]],
            ]
          end
        end
      end

      describe "through an Agent" do
        strategies.each do |strategy|
          it "returns the validated object (#{strategy})" do
            agent = Class.new(Riffer::Agent) do
              model acceptance_model_id(provider_name)
              instructions "Analyze the sentiment of the given text."
              structured_output strategy: strategy do
                required :sentiment, String, enum: %w[positive neutral negative], description: "The sentiment"
              end
            end.new

            response = acceptance_cassette("#{cassette_prefix}/agent/#{strategy}") do
              agent.generate("I love this product, it is amazing!")
            end

            expect(response.outcome.reason).must_equal :completed
            expect(response.structured_output).must_equal({ sentiment: "positive" })
          end

          it "calls a tool before the structured answer (#{strategy})" do
            weather_tool = acceptance_weather_tool
            agent = Class.new(Riffer::Agent) do
              model acceptance_model_id(provider_name)
              instructions "Answer weather questions. Always look the weather up with the tool."
              uses_tools [weather_tool]
              structured_output strategy: strategy do
                required :city, String, description: "The city"
                required :celsius, Integer, description: "The temperature in degrees Celsius"
              end
            end.new

            response = acceptance_cassette("#{cassette_prefix}/agent_tool/#{strategy}") do
              agent.generate("What is the weather in Toronto?")
            end

            expect(response.outcome.reason).must_equal :completed
            expect(response.structured_output).must_equal({ city: "Toronto", celsius: 15 })
            expect(response.messages.grep(Riffer::Messages::Tool)).wont_be_empty
          end
        end
      end
    end
  end
end
