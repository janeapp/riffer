# frozen_string_literal: true

require "test_helper"

describe Riffer::Testing do
  it "makes a stubbed tool findable by its derived identifier" do
    tool = stub_tool("StubbedKbSearch")

    expect(Riffer::Tool.find("stubbed_kb_search")).must_equal tool
  end

  it "evaluates the body in the stubbed tool" do
    tool = stub_tool("StubbedEcho") do
      description "Echoes a canned answer"

      def call(context:, **) = text("stubbed")
    end

    expect(tool.description).must_equal "Echoes a canned answer"
    expect(tool.new.call(context: nil).content).must_equal "stubbed"
  end

  it "makes a stubbed agent findable by its derived identifier" do
    agent = stub_agent("StubbedSupportAgent") { model "mock/riffer-1" }

    expect(Riffer::Agent.find("stubbed_support_agent")).must_equal agent
    expect(agent.model).must_equal "mock/riffer-1"
  end

  it "stubs onto an intermediate base class" do
    base = Class.new(Riffer::Tool)
    tool = stub_tool("StubbedChildTool", base: base)

    expect(base.find("stubbed_child_tool")).must_equal tool
    expect(Riffer::Tool.find("stubbed_child_tool")).must_be_nil
  end

  it "raises ArgumentError when neither a name nor a body identifier is given" do
    expect { stub_tool }.must_raise Riffer::ArgumentError
    expect { stub_tool { description "nameless" } }.must_raise Riffer::ArgumentError
  end

  it "raises DuplicateIdentifierError when the identifier is already taken" do
    stub_tool("StubbedDuplicate")

    expect { stub_tool { identifier "stubbed_duplicate" } }.must_raise Riffer::DuplicateIdentifierError
  end

  describe "a named stub" do
    it "assigns the constant and derives the identifier from it" do
      agent = stub_agent("StubbedNamedAgent")

      expect(Object.const_get(:StubbedNamedAgent)).must_equal agent
      expect(agent.identifier).must_equal "stubbed_named_agent"
      expect(Riffer::Agent.find("stubbed_named_agent")).must_equal agent
    end

    it "accepts a symbol name" do
      tool = stub_tool(:StubbedSymbolTool)

      expect(Object.const_get(:StubbedSymbolTool)).must_equal tool
      expect(Riffer::Tool.find("stubbed_symbol_tool")).must_equal tool
    end

    it "prefers an identifier declared in the body over the derived one" do
      tool = stub_tool("StubbedBodyTool") do
        identifier "stubbed_body_wins"
      end

      expect(Riffer::Tool.find("stubbed_body_wins")).must_equal tool
      expect(Riffer::Tool.find("stubbed_body_tool")).must_be_nil
    end

    it "raises ArgumentError for a name that is not a simple constant name" do
      expect { stub_tool("Riffer::StubbedNamespaced") }.must_raise Riffer::ArgumentError
      expect { stub_tool("stubbed_lowercase") }.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError when the constant is already defined" do
      Object.const_set(:StubbedTakenName, Module.new)

      expect { stub_tool("StubbedTakenName") }.must_raise Riffer::ArgumentError
      expect(Riffer::Tool.find("stubbed_taken_name")).must_be_nil
    ensure
      Object.send(:remove_const, :StubbedTakenName)
    end
  end

  describe "an anonymous stub" do
    it "registers under the identifier its body declares without naming a constant" do
      tool = stub_tool { identifier "stubbed_anonymous_tool" }

      expect(Riffer::Tool.find("stubbed_anonymous_tool")).must_equal tool
      expect(Riffer::Helpers::Identifier.real_name(tool)).must_be_nil
    end
  end

  describe "reset!" do
    it "unregisters tracked stubs newest first" do
      base = Class.new(Riffer::Tool)
      unregistered = []
      base.define_singleton_method(:unregister) do |klass|
        unregistered << klass.identifier
        super(klass)
      end
      stub_tool("FirstResetTool", base: base)
      stub_tool("SecondResetTool", base: base)

      Riffer::Testing.reset!

      expect(unregistered).must_equal %w[second_reset_tool first_reset_tool]
    end

    it "forgets the stubs it removed" do
      stub_tool("StubbedClearedTool")

      Riffer::Testing.reset!

      expect(Riffer::Tool.find("stubbed_cleared_tool")).must_be_nil
      expect(Riffer::Testing.registrations).must_be_empty
    end

    it "removes the constant a named stub created" do
      tool = stub_tool("StubbedResetTool")

      Riffer::Testing.reset!

      expect(Object.const_defined?(:StubbedResetTool, false)).must_equal false
      expect(Riffer::Tool.find("stubbed_reset_tool")).must_be_nil
      expect(Riffer::Tool.all).wont_include tool
    end

    it "leaves a constant the test has already replaced" do
      stub_tool("StubbedReplacedTool")
      replacement = Module.new
      Object.send(:remove_const, :StubbedReplacedTool)
      Object.const_set(:StubbedReplacedTool, replacement)

      Riffer::Testing.reset!

      expect(Object.const_get(:StubbedReplacedTool)).must_equal replacement
    ensure
      Object.send(:remove_const, :StubbedReplacedTool) if Object.const_defined?(:StubbedReplacedTool, false)
    end

    it "tolerates a constant the test has already removed" do
      tool = stub_tool("StubbedVanishedTool")
      Object.send(:remove_const, :StubbedVanishedTool)

      Riffer::Testing.reset!

      expect(Riffer::Tool.all).wont_include tool
    end

    it "is a no-op when nothing is stubbed" do
      Riffer::Testing.reset!

      expect(Riffer::Testing.registrations).must_be_empty
    end

    it "shares tracking between an including test case and the module" do
      tool = Riffer::Testing.stub_tool("StubbedModuleCall")

      reset!

      expect(Riffer::Tool.all).wont_include tool
    end
  end

  describe "the minitest adapter" do
    it "resets stubs once a test finishes" do
      test_case = Class.new(Minitest::Test) do
        def test_stubs_a_tool
          stub_tool("StubbedAdapterCleanup")
        end
      end

      test_case.new("test_stubs_a_tool").run

      expect(Riffer::Tool.find("stubbed_adapter_cleanup")).must_be_nil
    end
  end
end
