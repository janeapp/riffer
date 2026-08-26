# frozen_string_literal: true

require "test_helper"

describe Riffer::Tool do
  let(:weather_tool_class) do
    Class.new(Riffer::Tool) do
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
    Class.new(Riffer::Tool) do
      description "A simple tool"

      def call(context:, **_kwargs)
        text("Simple result")
      end
    end
  end

  describe "#call" do
    it "raises NotImplementedError when not implemented" do
      tool_class = Class.new(Riffer::Tool)
      tool = tool_class.new

      expect { tool.call(context: nil) }.must_raise(NotImplementedError)
    end

    it "executes with provided arguments" do
      tool = weather_tool_class.new
      result = tool.call(context: nil, city: "Toronto", units: "fahrenheit")

      expect(result.content).must_equal "Weather in Toronto: 20 fahrenheit"
    end

    it "receives context" do
      tool_class = Class.new(Riffer::Tool) do
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

    it "applies defaults for optional params" do
      tool = weather_tool_class.new
      result = tool.call_with_validation(context: nil, city: "Toronto")

      expect(result.content).must_equal "Weather in Toronto: 20 celsius"
    end

    it "passes context to call" do
      tool_class = Class.new(Riffer::Tool) do
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
      slow_tool_class = Class.new(Riffer::Tool) do
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
      slow_tool_class = Class.new(Riffer::Tool) do
        timeout 0.01

        def call(context:)
          sleep 0.02
          text("done")
        end
      end

      response = slow_tool_class.new.call_with_validation(context: nil)

      expect(response.content).must_match(/0\.01 seconds/)
    end

    it "completes successfully when within timeout" do
      fast_tool_class = Class.new(Riffer::Tool) do
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
      failing_tool_class = Class.new(Riffer::Tool) do
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
      failing_tool_class = Class.new(Riffer::Tool) do
        def call(context:)
          raise Riffer::ToolExecutionError, "Expected failure"
        end
      end

      response = failing_tool_class.new.call_with_validation(context: nil)

      expect(response.exception).must_be_nil
    end

    it "folds an arbitrary StandardError into an unhandled_error response" do
      buggy_tool_class = Class.new(Riffer::Tool) do
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
      buggy_tool_class = Class.new(Riffer::Tool) do
        def call(context:)
          nil.nonexistent_method
        end
      end

      response = buggy_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_match(/\AError executing tool: NoMethodError: /)
    end

    it "carries the rescued exception on an unhandled_error response" do
      buggy_tool_class = Class.new(Riffer::Tool) do
        def call(context:)
          raise "Something went wrong"
        end
      end

      response = buggy_tool_class.new.call_with_validation(context: nil)

      expect(response.exception).must_be_instance_of RuntimeError
      expect(response.exception.message).must_equal "Something went wrong"
    end

    it "returns an unhandled_error response when tool does not return Response" do
      bad_tool_class = Class.new(Riffer::Tool) do
        def call(context:)
          "raw string instead of Response"
        end
      end

      response = bad_tool_class.new.call_with_validation(context: nil)

      expect(response.error_type).must_equal :unhandled_error
      expect(response.content).must_match(/must return a Riffer::Tools::Response/)
    end

    it "raises NotImplementedError when call is not implemented" do
      tool_class = Class.new(Riffer::Tool)

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
