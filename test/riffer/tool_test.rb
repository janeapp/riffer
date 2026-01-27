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
        Riffer::Tools::Response.success("Weather in #{city}: 20 #{units || "celsius"}")
      end
    end
  end

  let(:simple_tool_class) do
    Class.new(Riffer::Tool) do
      description "A simple tool"

      def call(context:, **kwargs)
        Riffer::Tools::Response.success("Simple result")
      end
    end
  end

  describe ".description" do
    it "sets the description" do
      expect(weather_tool_class.description).must_equal "Gets the current weather"
    end

    it "returns nil when not set" do
      tool_class = Class.new(Riffer::Tool)
      expect(tool_class.description).must_be_nil
    end
  end

  describe ".identifier" do
    it "can be set explicitly" do
      tool_class = Class.new(Riffer::Tool)
      tool_class.identifier("my_custom_tool")
      expect(tool_class.identifier).must_equal "my_custom_tool"
    end
  end

  describe ".timeout" do
    it "returns 10 when not set" do
      tool_class = Class.new(Riffer::Tool)
      expect(tool_class.timeout).must_equal 10
    end

    it "sets the timeout value" do
      tool_class = Class.new(Riffer::Tool) do
        timeout 30
      end
      expect(tool_class.timeout).must_equal 30.0
    end

    it "converts to float" do
      tool_class = Class.new(Riffer::Tool) do
        timeout 15
      end
      expect(tool_class.timeout).must_be_instance_of Float
    end
  end

  describe ".params" do
    it "returns the params builder" do
      expect(weather_tool_class.params).must_be_instance_of Riffer::Tools::Params
    end

    it "returns nil when no params defined" do
      tool_class = Class.new(Riffer::Tool)
      expect(tool_class.params).must_be_nil
    end
  end

  describe ".name" do
    it "is an alias for identifier" do
      tool_class = Class.new(Riffer::Tool)
      tool_class.identifier("my_tool")
      expect(tool_class.name).must_equal "my_tool"
    end
  end

  describe ".parameters_schema" do
    it "returns JSON schema for params" do
      schema = weather_tool_class.parameters_schema
      expect(schema[:type]).must_equal "object"
    end

    it "includes properties from params" do
      schema = weather_tool_class.parameters_schema
      expect(schema[:properties].key?("city")).must_equal true
    end

    it "includes required array" do
      schema = weather_tool_class.parameters_schema
      expect(schema[:required]).must_include "city"
    end

    it "returns object type when no params" do
      tool_class = Class.new(Riffer::Tool)
      schema = tool_class.parameters_schema
      expect(schema[:type]).must_equal "object"
    end

    it "returns empty properties when no params" do
      tool_class = Class.new(Riffer::Tool)
      schema = tool_class.parameters_schema
      expect(schema[:properties]).must_equal({})
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
        def call(context:, **kwargs)
          Riffer::Tools::Response.success(context[:user_id])
        end
      end
      tool = tool_class.new
      result = tool.call(context: {user_id: 123})
      expect(result.content).must_equal "123"
    end
  end

  describe "#call_with_validation" do
    it "raises ValidationError for missing required params" do
      tool = weather_tool_class.new
      expect { tool.call_with_validation(context: nil) }.must_raise(Riffer::ValidationError)
    end

    it "includes param name in validation error message" do
      tool = weather_tool_class.new
      error = expect { tool.call_with_validation(context: nil) }.must_raise(Riffer::ValidationError)
      expect(error.message).must_match(/city is required/)
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
          Riffer::Tools::Response.success("#{context[:greeting]}, #{name}!")
        end
      end
      tool = tool_class.new
      result = tool.call_with_validation(context: {greeting: "Hello"}, name: "World")
      expect(result.content).must_equal "Hello, World!"
    end

    it "works without params definition" do
      tool = simple_tool_class.new
      result = tool.call_with_validation(context: nil)
      expect(result.content).must_equal "Simple result"
    end

    it "raises TimeoutError when execution exceeds timeout" do
      slow_tool_class = Class.new(Riffer::Tool) do
        timeout 0.01

        def call(context:)
          sleep 0.02
          Riffer::Tools::Response.success("done")
        end
      end

      tool = slow_tool_class.new
      expect { tool.call_with_validation(context: nil) }.must_raise(Riffer::TimeoutError)
    end

    it "includes timeout duration in error message" do
      slow_tool_class = Class.new(Riffer::Tool) do
        timeout 0.01

        def call(context:)
          sleep 0.02
          Riffer::Tools::Response.success("done")
        end
      end

      tool = slow_tool_class.new
      error = expect { tool.call_with_validation(context: nil) }.must_raise(Riffer::TimeoutError)
      expect(error.message).must_match(/0\.01 seconds/)
    end

    it "completes successfully when within timeout" do
      fast_tool_class = Class.new(Riffer::Tool) do
        timeout 1

        def call(context:)
          Riffer::Tools::Response.success("fast result")
        end
      end

      tool = fast_tool_class.new
      result = tool.call_with_validation(context: nil)
      expect(result.content).must_equal "fast result"
    end

    it "raises Error when tool does not return Response" do
      bad_tool_class = Class.new(Riffer::Tool) do
        def call(context:)
          "raw string instead of Response"
        end
      end

      tool = bad_tool_class.new
      error = expect { tool.call_with_validation(context: nil) }.must_raise(Riffer::Error)
      expect(error.message).must_match(/must return a Riffer::Tools::Response/)
    end
  end
end
