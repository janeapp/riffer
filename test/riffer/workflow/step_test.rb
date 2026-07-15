# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::Step do
  let(:step_class) do
    Class.new(Riffer::Workflow::Step) do
      input do
        required :message, String
      end

      output do
        required :formatted, String
      end

      def execute(message:)
        {formatted: message.upcase}
      end
    end
  end

  describe ".identifier" do
    it "derives from class name by default" do
      stub_const = Class.new(Riffer::Workflow::Step)
      def stub_const.name = "CategorizeRequest"

      expect(stub_const.identifier).must_equal "categorize_request"
    end

    it "accepts an explicit override" do
      klass = Class.new(Riffer::Workflow::Step)
      klass.identifier "custom_step"
      expect(klass.identifier).must_equal "custom_step"
    end
  end

  describe ".input" do
    it "returns the params builder" do
      expect(step_class.input).must_be_instance_of Riffer::Params
    end

    it "returns nil when not defined" do
      bare = Class.new(Riffer::Workflow::Step)
      expect(bare.input).must_be_nil
    end
  end

  describe ".output" do
    it "returns the params builder" do
      expect(step_class.output).must_be_instance_of Riffer::Params
    end

    it "returns nil when not defined" do
      bare = Class.new(Riffer::Workflow::Step)
      expect(bare.output).must_be_nil
    end
  end

  describe "#execute" do
    it "raises NotImplementedError when not overridden" do
      bare = Class.new(Riffer::Workflow::Step).new
      expect { bare.execute }.must_raise(NotImplementedError)
    end

    it "runs the implemented logic" do
      step = step_class.new
      result = step.execute(message: "hello")
      expect(result).must_equal({formatted: "HELLO"})
    end
  end

  describe "#context" do
    it "defaults to nil" do
      step = step_class.new
      expect(step.context).must_be_nil
    end

    it "is set at construction" do
      step = step_class.new(context: {patient_id: "p1"})
      expect(step.context[:patient_id]).must_equal "p1"
    end
  end

  describe ".uses" do
    it "returns an empty array by default" do
      bare = Class.new(Riffer::Workflow::Step)
      expect(bare.uses).must_equal []
    end

    it "stores declared dependencies" do
      dummy_agent = Class.new
      klass = Class.new(Riffer::Workflow::Step) { uses dummy_agent }
      expect(klass.uses).must_equal [dummy_agent]
    end

    it "accumulates across multiple calls" do
      agent_a = Class.new
      agent_b = Class.new
      klass = Class.new(Riffer::Workflow::Step) do
        uses agent_a
        uses agent_b
      end
      expect(klass.uses).must_equal [agent_a, agent_b]
    end

    it "rejects non-Module arguments" do
      expect {
        Class.new(Riffer::Workflow::Step) { uses "not_a_module" }
      }.must_raise Riffer::ArgumentError
    end
  end
end
