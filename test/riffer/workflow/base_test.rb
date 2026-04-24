# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::Base do
    describe ".input_schema" do
        it "throws an ArgumentError if input schema is invalid" do
            error = expect {
                Class.new(Riffer::Workflow::Base) do
                    input_schema "not a params object"
                end
            }.must_raise(Riffer::ArgumentError)
            expect(error.message).must_match(/input_schema must be a Riffer::Params/)
        end

        it "returns an input schema defined by a block" do
            klass = Class.new(Riffer::Workflow::Base) do
                input_schema do
                    required :name, String
                end
            end
            expect(klass.input_schema).must_be_instance_of(Riffer::Params)
            expect(klass.input_schema.parameters[0].name).must_equal(:name)
        end

        it "returns an input schema defined by a Riffer::Params object" do
            params = Riffer::Params.new do
                required :age, Integer
            end
            klass = Class.new(Riffer::Workflow::Base) do
                input_schema params
            end
            expect(klass.input_schema).must_equal(params)
        end
    end

    describe ".output_schema" do
        it "throws an ArgumentError if output schema is invalid" do
            error = expect {
                Class.new(Riffer::Workflow::Base) do
                    output_schema "not a params object"
                end
            }.must_raise(Riffer::ArgumentError)
            expect(error.message).must_match(/output_schema must be a Riffer::Params/)
        end

        it "returns an output schema defined by a block" do
            klass = Class.new(Riffer::Workflow::Base) do
                output_schema do
                    required :result, String
                end
            end
            expect(klass.output_schema).must_be_instance_of(Riffer::Params)
            expect(klass.output_schema.parameters[0].name).must_equal(:result)
        end

        it "returns an output schema defined by a Riffer::Params object" do
            params = Riffer::Params.new do
                required :message, String
            end
            klass = Class.new(Riffer::Workflow::Base) do
                output_schema params
            end
            expect(klass.output_schema).must_equal(params)
        end
    end

    describe ".step" do
        it "validates that the step_class is a subclass of Riffer::Workflow::Step" do
            error = expect {
                Class.new(Riffer::Workflow::Base) do
                    step "not a step class"
                end
            }.must_raise(Riffer::ArgumentError)
            expect(error.message).must_match(/step must be a class that inherits from Riffer::Workflow::Step/)
        end

        it "validates that the workflow has an input schema defined before adding steps" do
            error = expect {
                step1 = Class.new(Riffer::Workflow::Step) do
                    input_schema do
                        required :start_num, Integer
                    end
                    output_schema do
                        required :result, Integer
                    end
                    def execute(input)
                        {}
                    end
                end
                Class.new(Riffer::Workflow::Base) do
                    output_schema do
                        required :result, Integer
                    end
                    step step1
                end
            }.must_raise(Riffer::Workflow::ConfigurationError)
            expect(error.message).must_match(/Workflow input schema is not defined/)
        end

        it "validates that the workflow has an output schema defined before adding steps" do
            error = expect {
                step1 = Class.new(Riffer::Workflow::Step) do
                    input_schema do
                        required :start_num, Integer
                    end
                    output_schema do
                        required :result, Integer
                    end
                    def execute(input)
                        {}
                    end
                end
                Class.new(Riffer::Workflow::Base) do
                    input_schema do
                        required :start_num, Integer
                    end
                    step step1
                end
            }.must_raise(Riffer::Workflow::ConfigurationError)
            expect(error.message).must_match(/Workflow output schema is not defined/)
        end

        it "validates that the step has an input schema defined" do
            error = expect {
                step1 = Class.new(Riffer::Workflow::Step) do
                    output_schema do
                        required :result, Integer
                    end
                    def execute(input)
                        {}
                    end
                end
                Class.new(Riffer::Workflow::Base) do
                    input_schema do
                        required :start_num, Integer
                    end
                    output_schema do
                        required :result, Integer
                    end
                    step step1
                end
            }.must_raise(Riffer::Workflow::ConfigurationError)
            expect(error.message).must_match(/Input schema for step/)
            expect(error.message).must_match(/is not defined/)
        end

        it "validates that the step has an output schema defined" do
            error = expect {
                step1 = Class.new(Riffer::Workflow::Step) do
                    input_schema do
                        required :start_num, Integer
                    end
                    def execute(input)
                        {}
                    end
                end
                Class.new(Riffer::Workflow::Base) do
                    input_schema do
                        required :start_num, Integer
                    end
                    output_schema do
                        required :result, Integer
                    end
                    step step1
                end
            }.must_raise(Riffer::Workflow::ConfigurationError)
            expect(error.message).must_match(/Output schema for step/)
            expect(error.message).must_match(/is not defined/)
        end

        it "validates that the first step's input schema matches the workflow's input schema" do
            error = expect {
                step1 = Class.new(Riffer::Workflow::Step) do
                    input_schema do
                        required :age, Integer
                    end
                    output_schema do
                        required :result, String
                    end

                    def execute(input)
                        {}
                    end
                end
                Class.new(Riffer::Workflow::Base) do
                    input_schema do
                        required :name, String
                    end
                    output_schema do
                        required :age, Integer
                    end

                    step step1
                end
            }.must_raise(Riffer::Workflow::SchemaValidationError)
            expect(error.message).must_match(/not compatible with workflow input schema/)
        end

        it "validates that each step's output schema matches the next step's input schema" do
            error = expect {
                step1 = Class.new(Riffer::Workflow::Step) do
                    input_schema do
                        required :name, String
                    end
                    output_schema do
                        required :age, Integer
                    end

                    def execute(input)
                        {}
                    end
                end

                step2 = Class.new(Riffer::Workflow::Step) do
                    input_schema do
                        required :name, String
                    end
                    output_schema do
                        required :result, Integer
                    end

                    def execute(input)
                        {}
                    end
                end

                Class.new(Riffer::Workflow::Base) do
                    input_schema do
                        required :name, String
                    end
                    output_schema do
                        required :age, Integer
                    end
                    step step1
                    step step2
                end
            }.must_raise(Riffer::Workflow::SchemaValidationError)
            expect(error.message).must_match(/not compatible with input schema/)
        end

        it "adds the step to the workflow's steps" do
            step1 = Class.new(Riffer::Workflow::Step) do
                input_schema do
                    required :start_num, Integer
                end

                output_schema do
                    required :result, Integer
                end

                def execute(input)
                    {}
                end
            end

            klass = Class.new(Riffer::Workflow::Base) do
                input_schema do
                    required :start_num, Integer
                end
                output_schema do
                    required :result, Integer
                end
                step step1
            end

            expect(klass.steps).must_be_instance_of(Array)
            expect(klass.steps.length).must_equal(1)
            expect(klass.steps[0]).must_be_instance_of(step1)
        end
    end

    describe "#execute" do
        it "without steps throws a configuration error" do
            error = expect {
                Class.new(Riffer::Workflow::Base) do
                    input_schema do
                        required :start_num, Integer
                    end
                    output_schema do
                        required :result, Integer
                    end
                end.execute(start_num: 5)
            }.must_raise(Riffer::Workflow::ConfigurationError)
            expect(error.message).must_match(/No steps defined in workflow/)
        end

        it "validates that the last step's output schema matches the workflow's output schema" do
            step1 = Class.new(Riffer::Workflow::Step) do
                input_schema do
                    required :start_num, Integer
                end

                output_schema do
                    required :result, String
                end

                def execute(input)
                    { result: input[:start_num] + 1 }
                end
            end

            klass = Class.new(Riffer::Workflow::Base) do
                input_schema do
                    required :start_num, Integer
                end
                output_schema do
                    required :final_result, Integer
                end
                step step1
            end

            error = expect {
                klass.execute(start_num: 5)
            }.must_raise(Riffer::Workflow::SchemaValidationError)
            expect(error.message).must_match(/not compatible with workflow output schema/)
        end

        it "validates that the input schema matches the workflow's input schema" do
            step1 = Class.new(Riffer::Workflow::Step) do
                input_schema do
                    required :start_num, Integer
                end

                output_schema do
                    required :result, Integer
                end

                def execute(input)
                    { result: input[:start_num] + 1 }
                end
            end

            klass = Class.new(Riffer::Workflow::Base) do
                input_schema do
                    required :name, Integer
                end
                output_schema do
                    required :result, Integer
                end
                step step1
            end

            error = expect {
                klass.execute(name: "test")
            }.must_raise(Riffer::ValidationError)
            expect(error.message).must_match(/must be a integer/)
        end

        it "with step that raises error returns a workflow result with failed status and error message" do
            step1 = Class.new(Riffer::Workflow::Step) do
                input_schema do
                    required :start_num, Integer
                end

                output_schema do
                    required :result, Integer
                end

                def execute(input)
                    raise "Step failed"
                end
            end

            klass = Class.new(Riffer::Workflow::Base) do
                input_schema do
                    required :start_num, Integer
                end
                output_schema do
                    required :result, Integer
                end
                step step1
            end

            error = expect { klass.execute(start_num: 5) }.must_raise(Riffer::Workflow::StepExecutionError)
            expect(error.message).must_match(/Error executing step/)
            expect(error.message).must_match(/Step failed/)
            expect(error.results).must_be_instance_of(Riffer::Workflow::Result)
            expect(error.results.steps.length).must_equal(1)
            expect(error.results.steps[0].success).must_equal(false)
            expect(error.results.steps[0].error).must_equal("Step failed")
        end

        it "with successful steps returns a workflow result with succeeded status and final output" do
            step1 = Class.new(Riffer::Workflow::Step) do
                input_schema do
                    required :start_num, Integer
                end

                output_schema do
                    required :result, Integer
                end

                def execute(input)
                    { result: input[:start_num] + 1 }
                end
            end

            step2 = Class.new(Riffer::Workflow::Step) do
                input_schema do
                    required :result, Integer
                end

                output_schema do
                    required :final_result, Integer
                end

                def execute(input)
                    { final_result: input[:result] * 2 }
                end
            end

            klass = Class.new(Riffer::Workflow::Base) do
                input_schema do
                    required :start_num, Integer
                end
                output_schema do
                    required :final_result, Integer
                end
                step step1
                step step2
            end

            result = klass.execute(start_num: 5)
            expect(result.succeeded?).must_equal(true)
            expect(result.result).must_equal({ final_result: 12 })
            expect(result.steps.length).must_equal(2)
            expect(result.steps[0].success).must_equal(true)
            expect(result.steps[0].output).must_equal({ result: 6 })
            expect(result.steps[1].success).must_equal(true)
            expect(result.steps[1].output).must_equal({ final_result: 12 })
        end
    end
end