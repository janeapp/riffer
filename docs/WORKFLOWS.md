# Workflows

Workflows provide a DSL for defining multi-step, schema-validated pipelines that can combine custom logic steps with AI agent steps.  Each workflow enforces type safety through input and output schema validation and ensures data flows correctly between steps.

## How To Use

1. Declare steps
    a. Create a class by extending Riffer::Workflow::Step or Riffer::Workflow::AgentStep
    b. Set an input_schema and output_schema using the params syntax
    c. Define the execute(input) method
    d. For AgentStep, set the model, instructions, and any other Riffer::Agent attributes
2. Declare workflow
    a. Create a class by extending Riffer::Workflow::Base
    b. Set an input_schema and output_schema using the params syntax
    c. Add each step in the order of execution
        i. Validation will be performed with each call to `step`
3. Execute workflow
    a. Call WorkflowClass.execute({}), passing in the initial input hash
    b. Once complete, a Riffer::Workflow::Result will be returned
        i. result.succeeded?, result.failed? can be used to query success or failure
        ii. result.result returns the output hash of the last step
        iii. result.steps is an array of Riffer::Workflow::StepResult representing each step's input, output, and execution result
    c. If there is an error during execution, a Riffer::Workflow::StepExecutionError will be raised
        i. The error will have a `result` attribute that contains the Riffer::Workflow::Result representing the steps executed so far, the step that raised the error, and all inputs and outputs between steps
        ii. result.error returns the error message of the last executed step

## Basic Workflow with Custom Steps

```ruby
class AddOneStep < Riffer::Workflow::Step
  input_schema do
    required :input, Integer
  end

  output_schema do
    required :added, Integer
  end

  def execute(input)
    { added: input[:input] + 1 }
  end
end

class MultiplyByTwoStep < Riffer::Workflow::Step
  input_schema do
    required :added, Integer
  end

  output_schema do
    required :result, Integer
  end

  def execute(input)
    { result: input[:added] * 2 }
  end
end

class MathWorkflow < Riffer::Workflow::Base
  input_schema do
    required :input, Integer
  end

  output_schema do
    required :result, Integer
  end

  step AddOneStep
  step MultiplyByTwoStep
end

# Execution
result = MathWorkflow.execute({ input: 5 })
puts result.succeeded? # True
puts result.result # { result: 12 }
```

## Workflow with Agent Steps

```ruby
class PlusTenTool < Riffer::Tool
    description "Adds 10 to the passed in number"

    params do
        required :input, Integer, description: "The number to add 10 to"
    end

    def call(context:, input:)
        puts "invoking tool"
        json({ result: input + 10})
    end
end

# assumes openai provider has been configured
class AgenticPlusTenStep < Riffer::Workflow::AgentStep
    input_schema do
        required :result, Integer 
    end

    output_schema do
        required :final_result, Integer
    end

    model 'openai/gpt-5-mini'
    instructions "Call the plus_ten tool with the input and return the output"
    uses_tools [PlusTenTool]
end

class AgentWorkflow < Riffer::Workflow::Base
    input_schema do
        required :start_num, Integer 
    end

    output_schema do
        required :final_result, Integer
    end

    step AddOneStep
    step MultiplyByTwoStep
    step AgenticPlusTenStep
end

# Execution
result = AgentWorkflow.execute({ input: 5 })
puts result.succeeded? # True
puts result.result # { result: 22 }
```

## Error Handling

```ruby
begin
    result = MyWorkflow.execute({ input: 5})
rescue Riffer::Workflow::StepExecutionError => e
    # error during step execution
    puts e.message # "Error executing step #{step.class}: #{e.message}"
    puts e.results # Riffer::Workflow::Result with list of StepResults showing which steps have executed and which one failed with inputs and outputs
rescue Riffer::Workflow::SchemaValidationError => e
    # mismatch between input_schemas and output_schemas
    puts e.message
rescue Riffer::Workflow::ConfigurationError => e
    # attempting to execute with missing information, i.e. undefined input or output schema, no steps
    puts e.message
end
```

## Trade-offs and Design Decisions

1. Declarative schema and step syntax
    a. Matches existing Riffer::Agent syntax
    b. Requires up-front declaration over dynamic instantiation; can only load steps from code
2. Strict schema validation
    a. Schema is validated as soon as is practical rather than at execution / runtime
    b. Requires a verbose setup, but makes it clear when errors occur (i.e. as soon as an invalid step is added)
3. Riffer::Workflow::AgentStep uses `method_missing` ruby functionality
    a. Allows for extension and reuse of existing declarative syntax on Riffer::Agent
    b. "Magic code" that may cause debugging headaches later, but allows us to stick to the declarative syntax without a lot of duplicate passthrough code
4. Verbose step-by-step Riffer::Workflow::Result object
    a. Fully captures inputs, outputs, and results of each step in a workflow
    b. Large inputs, outputs, or workflow step chains will have an increased memory footprint in exchange for observability

## Future Improvements

- Logging
    - add the option for info/debug logging to trace execution steps as they happen
- Nested workflow execution
    - Being able to add other workflows as a step in a parent workflow
    - Need to make sure to prevent circular workflows (validation)
- Conditional execution
    - Defining conditions to trigger specific steps
- Parallel execution
    - Executing a set of steps at the same time and waiting for all steps to complete, and combining the results before proceeding
- Retry with backoff
    - in the case of step execution error, retry a set number of times with optional backoff delay
- Streaming
    - emitting results from each step as they're returned instead of at the end of the workflow execution

## Assumptions

- Validating parameters is based on name, type, required, item_type, and nested_params.  Description, enum, and default are ignored
- Optional parameters are ignored for validation
- Data between steps is transferred as Hashes
- Input hashes can be serialized as json for Riffer::Workflow::AgentStep
- Schemas do not change after steps and workflows are declared (validation is performed when declared)