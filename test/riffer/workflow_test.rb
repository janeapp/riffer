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

  let(:workflow) do
    workflow_class.new
  end

  describe "invalid workflows" do
    let(:workflow_class) do
      agent_class
      Class.new(Riffer::Workflow) do
        identifier "riffer/workflow"

        step :search1, Riffer::Agent
      end
    end
    describe "validate input when run workflow" do
      it "return response object with error for expected errors" do
        result = workflow.run(context: nil)

        expect(result).must_be_instance_of Riffer::Workflow::Response
        expect(result.error?).must_equal true
        expect(result.success?).must_equal false
        expect(result.error_type).must_equal :validation_error
        expect(result.error_message).must_equal "Invalid model string: "
      end
    end
  end

  describe "valid workflows" do
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
  end
end
