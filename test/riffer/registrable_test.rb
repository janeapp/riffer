# frozen_string_literal: true

require "test_helper"

# Named container so classes assigned beneath it get permanent names; each test
# removes the constants it creates (the classes stay named — that's fine).
# Every test builds a fresh anonymous base class, so its registry never
# collides with other tests' classes regardless of run order.
module RegistrableTestNamespace; end

describe Riffer::Registrable do
  after do
    RegistrableTestNamespace.constants.each do |const|
      RegistrableTestNamespace.send(:remove_const, const)
    end
  end

  def define_named_subclass(base, const_name, identifier: nil, &block)
    klass = Class.new(base, &block)
    klass.identifier(identifier) if identifier
    RegistrableTestNamespace.const_set(const_name, klass)
  end

  describe "on a Riffer::Tool lineage" do
    let(:base) { Class.new(Riffer::Tool) }

    it "finds a subclass by derived identifier" do
      tool = define_named_subclass(base, :AlphaTool)

      expect(base.find("registrable_test_namespace/alpha_tool")).must_equal tool
    end

    it "finds a subclass by explicit identifier" do
      tool = define_named_subclass(base, :BravoTool, identifier: "custom-tool")

      expect(base.find("custom-tool")).must_equal tool
    end

    it "accepts symbols" do
      tool = define_named_subclass(base, :CharlieTool, identifier: "symbol-tool")

      expect(base.find(:"symbol-tool")).must_equal tool
    end

    it "returns nil when no identifier matches" do
      define_named_subclass(base, :DeltaTool)

      expect(base.find("missing")).must_be_nil
    end

    it "returns all registered subclasses" do
      alpha = define_named_subclass(base, :AlphaTool)
      bravo = define_named_subclass(base, :BravoTool)

      expect(base.all.sort_by(&:to_s)).must_equal [alpha, bravo]
    end

    it "registers a subclass defined after the registry was built" do
      define_named_subclass(base, :AlphaTool)
      base.all

      late = define_named_subclass(base, :LateTool)

      expect(base.find("registrable_test_namespace/late_tool")).must_equal late
    end

    it "never registers anonymous subclasses, even with an explicit identifier" do
      anonymous = Class.new(base) { identifier "anonymous-tool" }

      expect(base.find("anonymous-tool")).must_be_nil
      expect(base.all).wont_include anonymous
    end

    it "does not register grandchildren on the grandparent" do
      child = define_named_subclass(base, :ChildTool)
      grandchild = define_named_subclass(child, :GrandchildTool)

      expect(base.find(grandchild.identifier)).must_be_nil
      expect(child.find(grandchild.identifier)).must_equal grandchild
    end

    it "raises DuplicateIdentifierError when two subclasses share an identifier" do
      define_named_subclass(base, :FirstDupTool, identifier: "dup-tool")
      define_named_subclass(base, :SecondDupTool, identifier: "dup-tool")

      error = expect { base.find("dup-tool") }.must_raise Riffer::DuplicateIdentifierError

      expect(error.message).must_include "dup-tool"
      expect(error.message).must_include "RegistrableTestNamespace::FirstDupTool"
      expect(error.message).must_include "RegistrableTestNamespace::SecondDupTool"
    end

    it "raises DuplicateIdentifierError again on subsequent lookups" do
      define_named_subclass(base, :FirstDupTool, identifier: "dup-tool")
      define_named_subclass(base, :SecondDupTool, identifier: "dup-tool")

      expect { base.find("dup-tool") }.must_raise Riffer::DuplicateIdentifierError
      expect { base.all }.must_raise Riffer::DuplicateIdentifierError
    end
  end

  describe "on a Riffer::Agent lineage" do
    let(:base) { Class.new(Riffer::Agent) }

    it "finds a subclass by derived identifier" do
      agent = define_named_subclass(base, :AlphaAgent) { model "mock/riffer-1" }

      expect(base.find("registrable_test_namespace/alpha_agent")).must_equal agent
    end

    it "finds a subclass by explicit identifier" do
      agent = define_named_subclass(base, :BravoAgent, identifier: "custom-agent") { model "mock/riffer-1" }

      expect(base.find("custom-agent")).must_equal agent
    end

    it "returns all registered subclasses" do
      alpha = define_named_subclass(base, :AlphaAgent) { model "mock/riffer-1" }
      bravo = define_named_subclass(base, :BravoAgent) { model "mock/riffer-1" }

      expect(base.all.sort_by(&:to_s)).must_equal [alpha, bravo]
    end

    it "never registers anonymous subclasses, even with an explicit identifier" do
      anonymous = Class.new(base) { identifier "anonymous-agent" }

      expect(base.find("anonymous-agent")).must_be_nil
      expect(base.all).wont_include anonymous
    end

    it "raises DuplicateIdentifierError when two subclasses share an identifier" do
      define_named_subclass(base, :FirstDupAgent, identifier: "dup-agent")
      define_named_subclass(base, :SecondDupAgent, identifier: "dup-agent")

      expect { base.find("dup-agent") }.must_raise Riffer::DuplicateIdentifierError
      expect { base.find("dup-agent") }.must_raise Riffer::DuplicateIdentifierError
    end
  end
end
