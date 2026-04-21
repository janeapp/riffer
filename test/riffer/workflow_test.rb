# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow do
  let(:agent_class) do
    Class.new(Riffer::Agent) do
      identifier "test-agent"
      model "mock/riffer-1"
      instructions "You are a helpful assistant."
    end
  end

  let(:agent) do
    agent_class.new
  end

  let(:workflow_class) do
    captured_agent = agent_class
    Class.new(Riffer::Workflow) do
      identifier "riffer/workflow"

      step :search1, captured_agent
    end
  end

  let(:weather_tool_class) do
    Class.new(Riffer::Tool) do
      description "Gets the current weather"

      params do
        required :city, String, description: "The city name"
        optional :units, String, default: "celsius"
      end

      def call(context:, city:, units: nil)
        text("Weather in #{city}: 20 #{units || "celsius"}")
      end
    end
  end

  let(:simple_tool_class) do
    Class.new(Riffer::Tool) do
      description "A simple tool"

      def call(context:, **kwargs)
        text("Simple result")
      end
    end
  end

  let(:slow_tool_class) do
    Class.new(Riffer::Tool) do
      description "A simple tool"

      def call(context:, **kwargs)
        sleep 0.02
        text("Simple result")
      end
    end
  end

  let(:workflow) do
    workflow_class.new
  end

  describe "workflows with errors" do
    let(:workflow_class) do
      agent_class
      Class.new(Riffer::Workflow) do
        identifier "riffer/workflow"

        step :search1, Riffer::Agent
      end
    end
    describe "validate input when run workflow" do
      it "return response object with error for a class that is not expected for step" do
        result = workflow.run(context: nil)

        expect(result).must_be_instance_of Riffer::Workflow::Response
        expect(result.error?).must_equal true
        expect(result.success?).must_equal false
        expect(result.error_type).must_equal :validation_error
        expect(result.error_message).must_equal "Invalid model string: "
      end
    end

    describe "workflow with multiple tools steps with dependencies" do
      let(:workflow_class) do
        captured_tool = weather_tool_class
        Class.new(Riffer::Workflow) do
          identifier "riffer/workflow"

          step :weather1, captured_tool
          step :weather2, captured_tool, depends_on: :weather1
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object with fail because the output of the first step does not match the input of the second one" do
            result = workflow.run(context: nil, city: "Toronto", units: "fahrenheit")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal false
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 1 # Just the first step ran
            expect(result.steps_response[:weather1]).must_be_instance_of Riffer::Tools::Response
          end
        end
      end
    end

    describe "workflow with multiple tools steps with dependencies2" do
      let(:workflow_class) do
        captured_tool = slow_tool_class
        Class.new(Riffer::Workflow) do
          timeout 0.01
          identifier "riffer/workflow"

          step :slowtool, captured_tool
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object with fail because the timeout on first step" do
            result = workflow.run(context: nil, city: "Toronto", units: "fahrenheit")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal false
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.error_message).must_equal "Step execution timed out after 0.01 seconds"
            expect(result.error_type).must_equal :execution_error
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 0
          end
        end
      end
    end
  end

  describe "workflows with no errors" do
    describe "workflow with no steps" do
      let(:workflow_class) do
        agent_class
        Class.new(Riffer::Workflow) do
          identifier "riffer/workflow"
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object" do
            result = workflow.run(context: nil, prompt: "What is the weather?")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal true
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 0
          end
        end
      end
    end

    describe "workflow with just one agent step" do
      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object" do
            result = workflow.run(context: nil, prompt: "What is the weather?")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal true
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 1
            expect(result.steps_response[:search1]).must_be_instance_of Riffer::Agent::Response
          end
        end
      end
    end

    describe "workflow with multiple agent steps" do
      let(:workflow_class) do
        captured_agent = agent_class
        Class.new(Riffer::Workflow) do
          identifier "riffer/workflow"

          step :search1, captured_agent
          step :search2, captured_agent
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object" do
            result = workflow.run(context: nil, prompt: "What is the weather?")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal true
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 2
            expect(result.steps_response[:search1]).must_be_instance_of Riffer::Agent::Response
            expect(result.steps_response[:search2]).must_be_instance_of Riffer::Agent::Response
          end
        end
      end
    end

    describe "workflow with multiple tools steps with no dependency" do
      let(:workflow_class) do
        captured_tool = weather_tool_class
        Class.new(Riffer::Workflow) do
          identifier "riffer/workflow"

          step :weather1, captured_tool
          step :weather2, captured_tool
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object with success" do
            result = workflow.run(context: nil, city: "Toronto", units: "fahrenheit")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal true
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 2
            expect(result.steps_response[:weather1]).must_be_instance_of Riffer::Tools::Response
            expect(result.steps_response[:weather2]).must_be_instance_of Riffer::Tools::Response
          end
        end
      end
    end

    describe "workflow with multiple tools steps with dependencies" do
      let(:workflow_class) do
        captured_tool = weather_tool_class
        captured_simple_tool_class = simple_tool_class
        Class.new(Riffer::Workflow) do
          identifier "riffer/workflow"

          step :weather1, captured_tool
          step :simpletool, captured_simple_tool_class, depends_on: :weather1
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object with success" do
            result = workflow.run(context: nil, city: "Toronto", units: "fahrenheit")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal true
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 2
            expect(result.steps_response[:weather1]).must_be_instance_of Riffer::Tools::Response
            expect(result.steps_response[:simpletool]).must_be_instance_of Riffer::Tools::Response
          end
        end
      end
    end

    describe "workflow with multiple agents and tools steps with dependencies" do
      let(:workflow_class) do
        captured_tool = weather_tool_class
        captured_simple_tool_class = simple_tool_class
        captured_agent = agent_class
        Class.new(Riffer::Workflow) do
          identifier "riffer/workflow"

          step :weather1, captured_tool
          step :search1, captured_agent, depends_on: :weather1
          step :simpletool, captured_simple_tool_class, depends_on: [:weather1, :search1]
          step :search2, captured_agent, depends_on: :simpletool
        end
      end

      describe "#run" do
        describe "with mock provider" do
          it "returns a Response object with success" do
            result = workflow.run(context: nil, city: "Toronto", units: "fahrenheit")

            expect(result).must_be_instance_of Riffer::Workflow::Response
            expect(result.success?).must_equal true
            expect(result.identifier).must_equal "riffer/workflow"
            expect(result.steps_response).must_be_instance_of Hash
            expect(result.steps_response.keys.length).must_equal 4
            expect(result.steps_response[:weather1]).must_be_instance_of Riffer::Tools::Response
            expect(result.steps_response[:search1]).must_be_instance_of Riffer::Agent::Response
            expect(result.steps_response[:simpletool]).must_be_instance_of Riffer::Tools::Response
            expect(result.steps_response[:search2]).must_be_instance_of Riffer::Agent::Response
          end
        end
      end
    end
  end
end
