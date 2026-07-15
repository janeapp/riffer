# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow do
  # -- Reusable step classes --------------------------------------------------

  let(:upcase_step) do
    Class.new(Riffer::Workflow::Step) do
      def self.name = "UpcaseStep"

      input do
        required :text, String
      end

      output do
        required :text, String
      end

      def execute(text:)
        {text: text.upcase}
      end
    end
  end

  let(:append_step) do
    Class.new(Riffer::Workflow::Step) do
      def self.name = "AppendStep"

      input do
        required :text, String
      end

      output do
        required :text, String
      end

      def execute(text:)
        {text: "#{text}!"}
      end
    end
  end

  let(:context_step) do
    Class.new(Riffer::Workflow::Step) do
      def self.name = "ContextStep"

      input do
        required :text, String
      end

      output do
        required :text, String
        required :clinic, String
      end

      def execute(text:)
        {text: text, clinic: context[:clinic_id]}
      end
    end
  end

  let(:failing_step) do
    Class.new(Riffer::Workflow::Step) do
      def self.name = "FailingStep"

      input do
        required :text, String
      end

      output do
        required :text, String
      end

      def execute(text:)
        raise "something went wrong"
      end
    end
  end

  let(:bad_output_step) do
    Class.new(Riffer::Workflow::Step) do
      def self.name = "BadOutputStep"

      input do
        required :text, String
      end

      output do
        required :result, String
      end

      def execute(text:)
        {wrong_key: text}
      end
    end
  end

  let(:no_schema_step) do
    Class.new(Riffer::Workflow::Step) do
      def self.name = "NoSchemaStep"

      def execute(text:)
        {text: text.reverse}
      end
    end
  end

  # -- Helpers ----------------------------------------------------------------

  def build_workflow(*step_classes)
    Class.new(Riffer::Workflow) do
      step_classes.each { |s| step s }
    end
  end

  # -- Tests ------------------------------------------------------------------

  describe ".identifier" do
    it "derives from class name" do
      klass = Class.new(Riffer::Workflow)
      def klass.name = "HelpDeskWorkflow"

      expect(klass.identifier).must_equal "help_desk_workflow"
    end

    it "accepts an explicit override" do
      klass = Class.new(Riffer::Workflow)
      klass.identifier "help_desk"
      expect(klass.identifier).must_equal "help_desk"
    end
  end

  describe ".step" do
    it "registers step classes in order" do
      wf = build_workflow(upcase_step, append_step)
      expect(wf.steps).must_equal [upcase_step, append_step]
    end

    it "rejects non-Step classes" do
      expect { build_workflow(String) }.must_raise Riffer::ArgumentError
    end

    it "rejects duplicate step identifiers" do
      expect {
        Class.new(Riffer::Workflow) do
          step_class = Class.new(Riffer::Workflow::Step) { def self.name = "DupStep" }
          step step_class
          step step_class
        end
      }.must_raise Riffer::ArgumentError
    end
  end

  describe "happy path" do
    it "runs steps sequentially and returns the final output" do
      wf = build_workflow(upcase_step, append_step)
      result = wf.execute({text: "hello"})

      expect(result.success?).must_equal true
      expect(result.output).must_equal({text: "HELLO!"})
    end

    it "captures the original input" do
      wf = build_workflow(upcase_step)
      result = wf.execute({text: "hello"})

      expect(result.input).must_equal({text: "hello"})
    end

    it "records per-step results with payload and output" do
      wf = build_workflow(upcase_step, append_step)
      result = wf.execute({text: "hello"})

      expect(result.steps.size).must_equal 2

      expect(result.steps["upcase_step"].payload).must_equal({text: "hello"})
      expect(result.steps["upcase_step"].output).must_equal({text: "HELLO"})

      expect(result.steps["append_step"].payload).must_equal({text: "HELLO"})
      expect(result.steps["append_step"].output).must_equal({text: "HELLO!"})
    end

    it "works via the instance form" do
      wf_class = build_workflow(upcase_step)
      wf = wf_class.new
      result = wf.execute(text: "hello")

      expect(result.success?).must_equal true
      expect(result.output).must_equal({text: "HELLO"})
    end

    it "serializes the full result via to_h" do
      wf = build_workflow(upcase_step)
      result = wf.execute({text: "hello"})

      expect(result.to_h).must_equal({
        status: :success,
        input: {text: "hello"},
        output: {text: "HELLO"},
        steps: {
          "upcase_step" => {status: :success, payload: {text: "hello"}, output: {text: "HELLO"}}
        }
      })
    end
  end

  describe "context passing" do
    it "makes context available inside steps" do
      wf = build_workflow(context_step)
      result = wf.execute({text: "hi"}, context: {clinic_id: "jane_demo"})

      expect(result.success?).must_equal true
      expect(result.output[:clinic]).must_equal "jane_demo"
    end

    it "passes context via instance form" do
      wf_class = build_workflow(context_step)
      wf = wf_class.new(context: {clinic_id: "west_clinic"})
      result = wf.execute(text: "hi")

      expect(result.output[:clinic]).must_equal "west_clinic"
    end

    it "does not mutate the caller's context hash" do
      original = {clinic_id: "jane_demo"}
      wf_class = build_workflow(context_step)
      wf_class.new(context: original).execute(text: "hi")

      expect(original).must_equal({clinic_id: "jane_demo"})
    end
  end

  describe "input validation errors" do
    it "fails when required input is missing" do
      wf = build_workflow(upcase_step)
      result = wf.execute({})

      expect(result.failed?).must_equal true
      expect(result.error).must_be_instance_of Riffer::ValidationError
      expect(result.error.message).must_match(/text is required/)
      expect(result.failed_step).must_equal "upcase_step"
    end

    it "fails when input type is wrong" do
      wf = build_workflow(upcase_step)
      result = wf.execute({text: 123})

      expect(result.failed?).must_equal true
      expect(result.error).must_be_instance_of Riffer::ValidationError
    end

    it "fails at the second step when output doesn't match next input" do
      mismatched_step = Class.new(Riffer::Workflow::Step) do
        def self.name = "MismatchedStep"

        input do
          required :text, String
        end

        output do
          required :number, Integer
        end

        def execute(text:)
          {number: text.length}
        end
      end

      wf = build_workflow(mismatched_step, upcase_step)
      result = wf.execute({text: "hello"})

      expect(result.failed?).must_equal true
      expect(result.failed_step).must_equal "upcase_step"
      expect(result.steps["mismatched_step"].success?).must_equal true
      expect(result.steps["upcase_step"].failed?).must_equal true
    end
  end

  describe "output validation errors" do
    it "fails when output is missing a required key" do
      wf = build_workflow(bad_output_step)
      result = wf.execute({text: "hello"})

      expect(result.failed?).must_equal true
      expect(result.error).must_be_instance_of Riffer::ValidationError
      expect(result.error.message).must_match(/result is required/)
      expect(result.failed_step).must_equal "bad_output_step"
    end

    it "fails when execute returns a non-Hash" do
      non_hash_step = Class.new(Riffer::Workflow::Step) do
        def self.name = "NonHashStep"

        input do
          required :text, String
        end

        def execute(text:)
          "not a hash"
        end
      end

      wf = build_workflow(non_hash_step)
      result = wf.execute({text: "hello"})

      expect(result.failed?).must_equal true
      expect(result.error).must_be_instance_of Riffer::ValidationError
      expect(result.error.message).must_match(/must return a Hash/)
    end
  end

  describe "execution errors" do
    it "captures the error and stops" do
      wf = build_workflow(upcase_step, failing_step, append_step)
      result = wf.execute({text: "hello"})

      expect(result.failed?).must_equal true
      expect(result.error).must_be_instance_of RuntimeError
      expect(result.error.message).must_equal "something went wrong"
      expect(result.failed_step).must_equal "failing_step"
    end

    it "marks later steps as pending" do
      wf = build_workflow(upcase_step, failing_step, append_step)
      result = wf.execute({text: "hello"})

      expect(result.steps["upcase_step"].success?).must_equal true
      expect(result.steps["failing_step"].failed?).must_equal true
      expect(result.steps["append_step"].pending?).must_equal true
    end

    it "preserves completed step output before the failure" do
      wf = build_workflow(upcase_step, failing_step)
      result = wf.execute({text: "hello"})

      expect(result.steps["upcase_step"].output).must_equal({text: "HELLO"})
    end
  end

  describe "steps without schemas" do
    it "skips validation when input/output are not declared" do
      wf = build_workflow(no_schema_step)
      result = wf.execute({text: "hello"})

      expect(result.success?).must_equal true
      expect(result.output).must_equal({text: "olleh"})
    end
  end

  describe "single-step workflow" do
    it "works with just one step" do
      wf = build_workflow(upcase_step)
      result = wf.execute({text: "hi"})

      expect(result.success?).must_equal true
      expect(result.output).must_equal({text: "HI"})
      expect(result.steps.size).must_equal 1
    end
  end

  describe "empty workflow" do
    it "returns success with the input as output" do
      wf = build_workflow
      result = wf.execute({text: "hi"})

      expect(result.success?).must_equal true
      expect(result.output).must_equal({text: "hi"})
    end

    it "works with context" do
      wf = build_workflow
      result = wf.execute({text: "hi"}, context: {user_id: "u1"})

      expect(result.success?).must_equal true
      expect(result.output).must_equal({text: "hi"})
    end
  end

  describe ".to_mermaid" do
    it "renders a multi-step pipeline in a subgraph" do
      wf = build_workflow(upcase_step, append_step)
      def wf.name = "TextWorkflow"

      expected = [
        "graph LR",
        "  subgraph text_workflow",
        "    upcase_step --> append_step",
        "  end"
      ].join("\n")

      expect(wf.to_mermaid).must_equal expected
    end

    it "renders a single-step workflow" do
      wf = build_workflow(upcase_step)
      def wf.name = "SingleWorkflow"

      expected = [
        "graph LR",
        "  subgraph single_workflow",
        "    upcase_step",
        "  end"
      ].join("\n")

      expect(wf.to_mermaid).must_equal expected
    end

    it "renders an empty workflow" do
      wf = build_workflow
      expect(wf.to_mermaid).must_equal "graph LR"
    end

    it "annotates steps that declare uses" do
      dummy_agent = Class.new do
        define_singleton_method(:name) { "ClassifierAgent" }
      end
      annotated_step = Class.new(Riffer::Workflow::Step) do
        define_singleton_method(:name) { "AnnotatedStep" }
        uses dummy_agent

        def execute(**) = {}
      end

      wf = build_workflow(annotated_step, upcase_step)
      def wf.name = "MixedWorkflow"

      mermaid = wf.to_mermaid
      expect(mermaid).must_include 'annotated_step["annotated_step · ClassifierAgent"]'
      expect(mermaid).must_include "--> upcase_step"
    end
  end

  describe ".describe" do
    it "prints the workflow summary" do
      wf = build_workflow(upcase_step, append_step)
      def wf.name = "TestWorkflow"

      output = capture_io { wf.describe }.first

      expect(output).must_include "test_workflow (2 steps)"
      expect(output).must_include "1. upcase_step  [text] → [text]"
      expect(output).must_include "2. append_step  [text] → [text]"
    end

    it "handles steps without schemas" do
      wf = build_workflow(no_schema_step)
      def wf.name = "NoSchemaWorkflow"

      output = capture_io { wf.describe }.first

      expect(output).must_include "1. no_schema_step  [] → []"
    end

    it "handles empty workflows" do
      wf = build_workflow
      def wf.name = "EmptyWorkflow"

      output = capture_io { wf.describe }.first
      expect(output).must_include "empty_workflow (0 steps)"
    end

    it "shows uses declarations" do
      dummy_tool = Class.new do
        define_singleton_method(:name) { "LookupTool" }
      end
      annotated_step = Class.new(Riffer::Workflow::Step) do
        define_singleton_method(:name) { "AnnotatedStep" }
        uses dummy_tool

        input { required :text, String }
        output { required :text, String }
        def execute(text:) = {text: text}
      end

      wf = build_workflow(annotated_step)
      def wf.name = "AnnotatedWorkflow"

      output = capture_io { wf.describe }.first

      expect(output).must_include "· LookupTool"
    end
  end
end
