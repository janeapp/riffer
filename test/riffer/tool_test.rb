# frozen_string_literal: true

require "test_helper"

describe Riffer::Tool do
  let(:weather_tool_class) do
    stub_tool("WeatherTool") do
      description "Gets the current weather"

      params do
        required :city, String, description: "The city name"
        optional :units, String, default: "celsius"
      end

      def call(context:, city:, units: nil)
        text("Weather in #{city}: 20 #{units || 'celsius'}")
      end
    end
  end

  let(:simple_tool_class) do
    stub_tool("SimpleTool") do
      description "A simple tool"

      def call(context:, **_kwargs)
        text("Simple result")
      end
    end
  end

  describe ".description" do
    it "sets and gets the description" do
      expect(weather_tool_class.description).must_equal "Gets the current weather"
    end

    it "returns nil when not set" do
      klass = Class.new(Riffer::Tool)

      expect(klass.description).must_be_nil
    end
  end

  describe ".identifier" do
    it "can be set explicitly" do
      klass = Class.new(Riffer::Tool)
      klass.identifier("custom_id")

      expect(klass.identifier).must_equal "custom_id"
    end
  end

  describe ".name" do
    it "is an alias for identifier" do
      klass = Class.new(Riffer::Tool)
      klass.identifier("my_tool")

      expect(klass.name).must_equal "my_tool"
    end
  end

  describe ".timeout" do
    it "returns DEFAULT_TIMEOUT when not set" do
      klass = Class.new(Riffer::Tool)

      expect(klass.timeout).must_equal 10
    end

    it "sets the timeout value" do
      klass = Class.new(Riffer::Tool) do
        timeout 30
      end

      expect(klass.timeout).must_equal 30.0
    end

    it "converts to float" do
      klass = Class.new(Riffer::Tool) do
        timeout 15
      end

      expect(klass.timeout).must_be_instance_of Float
    end
  end

  describe ".params" do
    it "returns the params builder" do
      expect(weather_tool_class.params).must_be_instance_of Riffer::Params
    end

    it "returns nil when no params defined" do
      klass = Class.new(Riffer::Tool)

      expect(klass.params).must_be_nil
    end
  end

  describe ".parameters_schema" do
    it "returns JSON schema for params" do
      schema = weather_tool_class.parameters_schema

      expect(schema[:type]).must_equal "object"
      expect(schema[:properties].key?("city")).must_equal true
      expect(schema[:required]).must_include "city"
    end

    it "returns empty schema when no params defined" do
      klass = Class.new(Riffer::Tool)
      schema = klass.parameters_schema

      expect(schema[:type]).must_equal "object"
      expect(schema[:properties]).must_equal({})
    end

    describe "with a Hash param that has no block" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "apply_rule"
          description "Applies a rule"

          params do
            required :applies_when, Hash
          end
        end
      end

      it "raises ArgumentError in strict mode" do
        error = expect { tool_class.parameters_schema(strict: true) }.must_raise(Riffer::ArgumentError)

        expect(error.message).must_equal(
          "applies_when: a Hash param requires a block defining its properties under strict schemas",
        )
      end

      it "renders the schema in non-strict mode" do
        expect(tool_class.parameters_schema[:properties]["applies_when"]).must_equal(type: "object")
      end
    end

    describe "with an AnyOf param" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "find_patient"
          description "Finds a patient"

          params do
            required :lookup, Riffer::Params::AnyOf do
              variant { required :email, String }
              variant { required :phone, String }
            end
          end
        end
      end

      it "renders each variant in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["lookup"]).must_equal(
          anyOf: [
            {
              type: "object",
              properties: { "email" => { type: "string" } },
              required: ["email"],
              additionalProperties: false,
            },
            {
              type: "object",
              properties: { "phone" => { type: "string" } },
              required: ["phone"],
              additionalProperties: false,
            },
          ],
        )
      end
    end

    describe "with an AnyOf param of primitive variants" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "set_quantity"
          description "Sets a quantity"

          params do
            optional :quantity, Riffer::Params::AnyOf do
              variant Integer
              variant String
            end
          end
        end
      end

      it "renders each variant and a null branch in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["quantity"]).must_equal(
          anyOf: [{ type: "integer" }, { type: "string" }, { type: "null" }],
        )
      end
    end

    describe "with an array of enum values" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "tag_ticket"
          description "Tags a ticket"

          params do
            required :tags, Array, of: String, enum: %w[urgent billing]
          end
        end
      end

      it "renders the enum on the items in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["tags"]).must_equal(
          type: "array", items: { type: "string", enum: %w[urgent billing] },
        )
      end
    end

    describe "with a format" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "book_visit"
          description "Books a visit"

          params do
            optional :on, String, format: "date"
          end
        end
      end

      it "renders the format next to the nullable type in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["on"]).must_equal(
          type: %w[string null], format: "date",
        )
      end
    end

    describe "with an array of arrays" do
      let(:tool_class) do
        Class.new(Riffer::Tool) do
          identifier "plot_route"
          description "Plots a route"

          params do
            optional :points, Array, of: [Float]
          end
        end
      end

      it "makes only the field nullable in strict mode" do
        expect(tool_class.parameters_schema(strict: true)[:properties]["points"]).must_equal(
          type: %w[array null], items: { type: "array", items: { type: "number" } },
        )
      end
    end
  end

  describe ".to_tool_schema" do
    it "returns a provider-agnostic schema hash" do
      weather_tool_class.identifier("test_tool")
      schema = weather_tool_class.to_tool_schema

      expect(schema[:name]).must_equal "test_tool"
      expect(schema[:description]).must_equal "Gets the current weather"
      expect(schema[:parameters_schema][:type]).must_equal "object"
    end

    it "passes strict option through" do
      schema = weather_tool_class.to_tool_schema(strict: true)

      expect(schema[:parameters_schema][:required]).must_include "units"
    end
  end

  describe ".validate_as_tool!" do
    it "raises when description is missing" do
      klass = Class.new(Riffer::Tool)

      expect { klass.validate_as_tool! }.must_raise(Riffer::ArgumentError)
    end

    it "succeeds when description and identifier are present" do
      klass = Class.new(Riffer::Tool) do
        description "Valid tool"
      end
      klass.identifier("valid_tool")

      expect(klass.validate_as_tool!).must_equal true
    end
  end

  describe "#call" do
    it "raises NotImplementedError when not implemented" do
      tool_class = stub_tool("Tool")
      tool = tool_class.new

      expect { tool.call(context: nil) }.must_raise(NotImplementedError)
    end

    it "executes with provided arguments" do
      tool = weather_tool_class.new
      result = tool.call(context: nil, city: "Toronto", units: "fahrenheit")

      expect(result.content).must_equal "Weather in Toronto: 20 fahrenheit"
    end

    it "receives context" do
      tool_class = stub_tool("Tool") do
        def call(context:, **_kwargs)
          text(context[:user_id])
        end
      end
      tool = tool_class.new
      result = tool.call(context: { user_id: 123 })

      expect(result.content).must_equal "123"
    end
  end

  describe "#call_with_validation" do
    it "returns a validation_error response for missing required params" do
      tool = weather_tool_class.new
      response = tool.call_with_validation(context: nil)

      expect(response.error?).must_equal true
      expect(response.error_type).must_equal :validation_error
    end

    it "includes param name in validation error message" do
      tool = weather_tool_class.new
      response = tool.call_with_validation(context: nil)

      expect(response.content).must_match(/city is required/)
    end

    it "returns a validation_error response for a value outside its format" do
      tool_class = stub_tool("Tool") do
        params do
          required :on, String, format: "date"
        end

        def call(context:, on:)
          text(on)
        end
      end
      response = tool_class.new.call_with_validation(context: nil, on: "next Tuesday")

      expect(response.error_type).must_equal :validation_error
      expect(response.content).must_equal "on must be a valid date"
    end

    it "returns a validation_error response for a nested array item of the wrong type" do
      tool_class = stub_tool("Tool") do
        params do
          required :points, Array, of: [Float]
        end

        def call(context:, points:)
          text(points.inspect)
        end
      end
      response = tool_class.new.call_with_validation(context: nil, points: [[43.6, "-79.4"]])

      expect(response.error_type).must_equal :validation_error
      expect(response.content).must_equal "points[0][1] must be a number"
    end

    it "applies defaults for optional params" do
      tool = weather_tool_class.new
      result = tool.call_with_validation(context: nil, city: "Toronto")

      expect(result.content).must_equal "Weather in Toronto: 20 celsius"
    end

    it "passes context to call" do
      tool_class = stub_tool("Tool") do
        params do
          required :name, String
        end

        def call(context:, name:)
          text("#{context[:greeting]}, #{name}!")
        end
      end
      tool = tool_class.new
      result = tool.call_with_validation(context: { greeting: "Hello" }, name: "World")

      expect(result.content).must_equal "Hello, World!"
    end

    it "works without params definition" do
      tool = simple_tool_class.new
      result = tool.call_with_validation(context: nil)

      expect(result.content).must_equal "Simple result"
    end

    it "returns a timeout_error response when execution exceeds timeout" do
      slow_tool_class = stub_tool("SlowTool") do
        timeout 0.01

        def call(context:)
          sleep 0.02
          text("done")
        end
      end

      response = slow_tool_class.new.call_with_validation(context: nil)

      expect(response.error?).must_equal true
      expect(response.error_type).must_equal :timeout_error
    end

    it "includes timeout duration in error message" do
      slow_tool_class = stub_tool("SlowTool") do
        timeout 0.01

        def call(context:)
          sleep 0.02
          text("done")
        end
      end

      response = slow_tool_class.new.call_with_validation(context: nil)

      expect(response.content).must_match(/0\.01 seconds/)
    end

    it "returns an unhandled_error response for a Timeout::Error raised by the tool body" do
      external_timeout_tool_class = stub_tool("ExternalTimeoutTool") do
        def call(context:)
          raise Timeout::Error, "external service timed out"
        end
      end

      response = external_timeout_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_equal "Error executing tool: Timeout::Error: external service timed out"
    end

    it "returns a timeout_error response for a Riffer::TimeoutError raised by the tool body" do
      timeout_raising_tool_class = stub_tool("TimeoutRaisingTool") do
        def call(context:)
          raise Riffer::TimeoutError
        end
      end

      response = timeout_raising_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :timeout_error
    end

    it "returns an unhandled_error response for a Riffer::ValidationError raised by the tool body" do
      validation_raising_tool_class = stub_tool("ValidationRaisingTool") do
        def call(context:)
          raise Riffer::ValidationError, "nested validation failed"
        end
      end

      response = validation_raising_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_equal "Error executing tool: Riffer::ValidationError: nested validation failed"
    end

    it "completes successfully when within timeout" do
      fast_tool_class = stub_tool("FastTool") do
        timeout 1

        def call(context:)
          text("fast result")
        end
      end

      tool = fast_tool_class.new
      result = tool.call_with_validation(context: nil)

      expect(result.content).must_equal "fast result"
    end

    it "returns an execution_error response for ToolExecutionError" do
      failing_tool_class = stub_tool("FailingTool") do
        def call(context:)
          raise Riffer::ToolExecutionError, "Expected failure"
        end
      end

      response = failing_tool_class.new.call_with_validation(context: nil)

      expect(response.error?).must_equal true
      expect(response.error_type).must_equal :execution_error
      expect(response.content).must_equal "Expected failure"
    end

    it "carries no exception on a deliberate error response" do
      failing_tool_class = stub_tool("FailingTool") do
        def call(context:)
          raise Riffer::ToolExecutionError, "Expected failure"
        end
      end

      response = failing_tool_class.new.call_with_validation(context: nil)

      expect(response.exception).must_be_nil
    end

    it "folds an arbitrary StandardError into an unhandled_error response" do
      buggy_tool_class = stub_tool("BuggyTool") do
        def call(context:)
          raise "Something went wrong"
        end
      end

      response = buggy_tool_class.new.call_with_validation(context: nil)

      expect(response.error?).must_equal true
      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_equal "Error executing tool: RuntimeError: Something went wrong"
    end

    it "folds a programming bug into an unhandled_error response" do
      buggy_tool_class = stub_tool("BuggyTool") do
        def call(context:)
          nil.nonexistent_method
        end
      end

      response = buggy_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_match(/\AError executing tool: NoMethodError: /)
    end

    it "carries the rescued exception on an unhandled_error response" do
      buggy_tool_class = stub_tool("BuggyTool") do
        def call(context:)
          raise "Something went wrong"
        end
      end

      response = buggy_tool_class.new.call_with_validation(context: nil)

      expect(response.exception).must_be_instance_of RuntimeError
      expect(response.exception.message).must_equal "Something went wrong"
    end

    it "returns an unhandled_error response when tool does not return Response" do
      bad_tool_class = stub_tool("BadTool") do
        def call(context:)
          "raw string instead of Response"
        end
      end

      response = bad_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_match(/must return a Riffer::Tools::Response/)
    end

    it "raises NotImplementedError when call is not implemented" do
      tool_class = stub_tool("Tool")

      expect { tool_class.new.call_with_validation(context: nil) }.must_raise(NotImplementedError)
    end
  end

  describe "#text" do
    it "creates a text response" do
      tool = simple_tool_class.new
      response = tool.text("hello")

      expect(response).must_be_instance_of Riffer::Tools::Response
      expect(response.content).must_equal "hello"
      expect(response.success?).must_equal true
    end
  end

  describe "#json" do
    it "creates a JSON response" do
      tool = simple_tool_class.new
      response = tool.json({ name: "Alice" })

      expect(response).must_be_instance_of Riffer::Tools::Response
      expect(response.content).must_equal '{"name":"Alice"}'
      expect(response.success?).must_equal true
    end
  end

  describe "#error" do
    it "creates an error response" do
      tool = simple_tool_class.new
      response = tool.error("something failed")

      expect(response).must_be_instance_of Riffer::Tools::Response
      expect(response.content).must_equal "something failed"
      expect(response.error?).must_equal true
    end

    it "accepts custom error type" do
      tool = simple_tool_class.new
      response = tool.error("not found", type: :not_found)

      expect(response.error_type).must_equal :not_found
    end
  end
end
