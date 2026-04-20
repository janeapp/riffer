# Workflows

This tech design describes the architecture and decisions to implement a minimum viable workflow feature
in Riffer.
The rest of this document is organized as follows: Section [1. Introduction](#1-introduction) describes the problem we are resolving in detail,
Section [2. Assumptions](#2-Assumptions) list all the assumptions made with explanations of each one. The section [3. Design](#3-design) presents the solution. The section [4. What should we build next?](#4-what-should-we-build-next) Organize the next steps of this work. The section [5. Implementation](#5-implementation) describes the implementation in detail.

# 1. Introduction
Riffer (https://github.com/janeapp/riffer) is the largest Ruby AI-powered framework developed by Jane App.
Riffer simplifies the process of creating AI agents in Ruby without coupling your application to an AI model/provider. So, you can create your AI-Agent using Riffer and later decide which model and provider to use.

Riffer has 2 important concepts: Agents and Tools. Agents are an abstraction of an AI-Agent. You can create your AI-Agent using this class and later choose the model. Tools are pieces of code or functionality that your AI-Agent can use.

So, let's see a simple example of it in action. Imagine that we want to create an agent that returns the temperature in a city in Celsius. Using Riffer, we can do this by creating an agent responsible for answering this question.
We also need 2 tools: one to scrape the temperature of a city from a website and another to convert temperatures from Fahrenheit to Celsius.

Keep in mind that this is just an example; there is a better way to do this instead of using 2 tools. The Riffer documentation, for example, shows how to do this with just one tool. The purpose of the exercise here is to exemplify
and discuss the problem.

```ruby
class TemperatureAgent < Riffer::Agent
  model 'select the model here'
  instructions 'You are a helpful assistant who helps users get the temperature of a city. Given a {city}, use the tools to get the temperature in Fahrenheit in this specific city, convert it to Celsius and return it to the user.'
  uses_tools [WeatherTool, TemperatureConversion]
end


class WeatherTool < Riffer::Tool
  description "Gets the current weather for a city."

  params do
    required :city, String, description: "The city name."
  end

  def call(context:, city:, units: nil)
    weather = WeatherAPI.fetch(city, units: "fahrenheit")
    text(weather.temperature)
  end
end


class TemperatureConversion < Riffer::Tool
  description "Convert the temperature from Fahrenheit to Celsius."

  params do
    required :temperature, Float, description: "The temperature in Fahrenheit."
  end

  def call(context:, temperature:)
    result = (temperature − 32) * 5.0 / 9
    text(result)
  end
end
```

This example shows that the Agent is acting like an orchestrator of the tools. Also, what if we want to run 2 different agents to compose our answer? This is the problem we are resolving with this new feature, Workflows.

`Workflows` are a simple way to run multiple agents, tools, and other workflows in a serial, step-by-step manner.
From the example above, the agent will no longer use the tools; it will be the first step in our workflow. The output of this will be the input to the `WeatherTool`, and the output of the `WeatherTool` will be the input to the `TemperatureConversion` tool.
The `Workflow` will run step by step and return all the outputs in a structured way for the user. We can rewrite the example above using this new feature as follows:
```ruby

   class MyWorkflow < Riffer::Workflow
     step :weather, WheatherTool
     step :temperature_conversion, TemperatureConversion, depends_on: :weather
   end

   workflow = MyWorkflow.new
   workflow.run(context:nil, city: 'toronto', units: 'fahrenheit')
```

# 1.1 In Scope

1. A workflow is composed of multiple steps, each of which could be:
    * Agent: The Agent class as defined in Riffer
    * Tool: The Tool class as defined in Riffer
    * Workflow: Another workflow.
2. No dependencies: Everything is made with just Riffer and Ruby.
3. Sequential composition: Workflows do not provide parallelism, branching, looping, suspend/resume, or streaming. Also, it is not thread-safe.
4. Single process, in-memory execution.
5. Valid inputs when the step provides validation

# 1.2 Not in scope

1. Parallelism and thread-safe
2. Data Persistence: Every result is in memory; nothing is persistent on disk.
3. suspend/resume: We cannot pause execution and resume it later.


# 2. Assumptions
For this proof of concept, we made some assumptions that guide our solution:

1. A step can depend on any previous steps, including multiple dependencies.
2. When `structure_output` is available in the result of a step, use it instead of raw output.
4. Steps are finite and fit in memory
5. The Workflow Results fit in memory


# 3. Design
```
    +---------------------------+
    |      Riffer::Workflow     |
    | (Base Class for Workflows)|
    +---------------------------+
           |     ^
           |     | Inherits from Riffer::Toolable
           v     |
    +---------------------------+
    |   MyWorkflow (Subclass)   |
    | (e.g., MyWorkflow <  Riffer::Workflow)
    +---------------------------+
           |
           |  Defines steps using DSL:
           |  `step :name, StepClass, depends_on: [...]`
           v
    +---------------------------+       +---------------------------+
    |  Step Definition Storage  |<-----|  Riffer::Agent / Riffer::Tool / |
    | (@steps Array of Hashes)   |       |  Riffer::Workflow (Step Classes) |
    +---------------------------+       +---------------------------+
           |
           |  `run(context:, **kwargs)` method initiates execution
           v
    +---------------------------------------------------------------------------------------------------------------------------------+
    |                                                   Workflow Execution Flow                                                       |
    +---------------------------------------------------------------------------------------------------------------------------------+
    |                                                                                                                                 |
    |  1. Initialize: `@context`, `@default_input` (initial `kwargs`)                                                                 |
    |                                                                                                                                 |
    |  2. Iterate through `self.class.steps` (defined order, but execution respects dependencies)                                     |
    |                                                                                                                                 |
    |     +-----------------------------------------------------------------------------------------------------+                     |
    |     |  For Each Step (`step_config`)                                                                      |                     |
    |     |                                                                                                     |                     |
    |     |  a. `generate_validated_args(step_config)`                                                          |                     |
    |     |     - Gathers inputs:                                                                               |                     |
    |     |       - If `depends_on` is empty: Uses `@default_input`                                             |                     |
    |     |       - If `depends_on` present: Slices `@results` (outputs from completed upstream steps)          |                     |
    |     |     - Transforms step results (e.g., `structured_output`, `content`, `to_h`)                        |                     |
    |     |     - Validates arguments via `step_class.params` (if defined)                                      |                     |
    |     |                                                                                                     |                     |
    |     |  b. `Timeout.timeout(self.class.timeout)`                                                           |                     |
    |     |     +---------------------------------------------------------------------------------------------+ |                     |
    |     |     |  Execute Step:                                                                              | |                     |
    |     |     |  - Creates `step = step_config[:step_class].new`                                           | |                     |
    |     |     |  - **Case Statement:**                                                                      | |                     |
    |     |     |    - **When `Riffer::Agent`:** Calls `step.generate(prompt, files:, context: @context)`     | |                     |
    |     |     |    - **When `Riffer::Tool`:** Calls `step.call(**validated_args)`                            | |                     |
    |     |     |    - **When `Riffer::Workflow`:** Calls `step.run(**validated_args)`                         | |                     |
    |     |     +---------------------------------------------------------------------------------------------+ |                     |
    |     |                                                                                                     |                     |
    |     |  c. Stores `result` in `@results` hash (keyed by step name)                                         |                     |
    |     +-----------------------------------------------------------------------------------------------------+                     |
    |                                                                                                                                 |
    |  3. Final Result:                                                                                                               |
    |     - On Success: `Riffer::Workflow::Response.success(identifier:, steps_response: @results)`                                   |
    |     - On Error (Timeout, Validation, Argument, Riffer::Error): `Riffer::Workflow::Response.error(...)`                          |
    |                                                                                                                                 |
    +---------------------------------------------------------------------------------------------------------------------------------+
```

The solution will consist of just one main class, `Riffer::Workflow`. When a user needs to write their workflow, they must subclass this class.
The steps are defined as a very simple DSL that allows the user to specify the dependencies between steps.
After defining the subclass and its steps, the user just needs to create a new instance of the class and call the `run` method. To execute the workflow.
After execution, the workflow will return a `Riffer::Workflow::Response` containing the responses for all steps and a `success?` field to check the solution status.


# 4. What should we build next?
1. Input declaration for workflow: Including input declaration allows us to validate the inputs.
2. Parallel execution: We can run steps in parallel when there is no explicit dependency
3. Pause/Resume: We do not have a way to pause and resume an exception
4. Persistency: We do not have a way to save the data to disk during execution. In a large workflow, persistence, along with pause/resume, is a must-have production feature.
5. Retries: We should be able to retry a step based on the error. For example, if fetching a website results in a timeout or connection error, it could be retried. Also, limited the number of retries.

# 5. Implementation
This section describes the implementation plan:

1. The first commit is this tech design to provide context and share the assumptions and decisions.
2. The second commit will include the new class Workflow, allowing users to define the steps, for now just Agent and execute the workflow.
3. The third commit includes the Tool as a possible step in a workflow
4. The last commit includes the workflow as a step for a workflow.
