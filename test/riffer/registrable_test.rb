# frozen_string_literal: true

require "test_helper"

require "tmpdir"

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

  describe "liveness of implicit registrations" do
    let(:base) { Class.new(Riffer::Tool) }

    it "skips a subclass whose constant has been removed" do
      tool = define_named_subclass(base, :EphemeralTool, identifier: "ephemeral-tool")
      RegistrableTestNamespace.send(:remove_const, :EphemeralTool)

      expect(base.find("ephemeral-tool")).must_be_nil
      expect(base.all).wont_include tool
    end

    it "skips a stale generation sharing a name with a live subclass" do
      stale = define_named_subclass(base, :ReloadedTool, identifier: "reloaded-tool")
      RegistrableTestNamespace.send(:remove_const, :ReloadedTool)
      live = define_named_subclass(base, :ReloadedTool, identifier: "reloaded-tool")

      expect(base.find("reloaded-tool")).must_equal live
      expect(base.all).wont_include stale
    end

    it "skips a subclass whose constant now points elsewhere" do
      tool = define_named_subclass(base, :ReplacedTool, identifier: "replaced-tool")
      RegistrableTestNamespace.send(:remove_const, :ReplacedTool)
      RegistrableTestNamespace.const_set(:ReplacedTool, Class.new)

      expect(base.find("replaced-tool")).must_be_nil
      expect(base.all).wont_include tool
    end

    it "leaves a pending autoload for a superseded generation untouched" do
      Dir.mktmpdir("registrable-autoload") do |dir|
        stale = define_named_subclass(base, :AutoloadedTool, identifier: "autoloaded-tool")
        RegistrableTestNamespace.send(:remove_const, :AutoloadedTool)
        # The autoloaded file cannot name the anonymous base, so it reads it back
        # out of the thread rather than through a constant the registry would see.
        Thread.current[:registrable_autoload_base] = base
        path = File.join(dir, "autoloaded_tool.rb")
        File.write(path, <<~RUBY)
          RegistrableTestNamespace.const_set(
            :AutoloadedTool,
            Class.new(Thread.current[:registrable_autoload_base]) { identifier "autoloaded-tool" },
          )
        RUBY
        RegistrableTestNamespace.autoload(:AutoloadedTool, path)

        expect(base.all).wont_include stale
        expect(RegistrableTestNamespace.autoload?(:AutoloadedTool)).must_equal path

        live = RegistrableTestNamespace::AutoloadedTool

        expect(base.find("autoloaded-tool")).must_equal live
      ensure
        Thread.current[:registrable_autoload_base] = nil
      end
    end
  end

  describe "register" do
    let(:base) { Class.new(Riffer::Tool) }

    it "registers an anonymous class under its explicit identifier" do
      tool = Class.new(base) { identifier "registered-tool" }

      base.register(tool)

      expect(base.find("registered-tool")).must_equal tool
      expect(base.all).must_equal [tool]
    end

    it "registers an anonymous agent class" do
      agent_base = Class.new(Riffer::Agent)
      agent = Class.new(agent_base) { identifier "registered-agent" }

      agent_base.register(agent)

      expect(agent_base.find("registered-agent")).must_equal agent
    end

    it "raises ArgumentError when the identifier is blank" do
      tool = Class.new(base)

      error = expect { base.register(tool) }.must_raise Riffer::ArgumentError

      expect(error.message).must_include "identifier"
    end

    it "raises ArgumentError for a class that is not a direct subclass" do
      child = define_named_subclass(base, :ChildTool)
      grandchild = Class.new(child) { identifier "grandchild-tool" }

      expect { base.register(grandchild) }.must_raise Riffer::ArgumentError
    end

    it "raises ArgumentError for a class outside the lineage" do
      error = expect { base.register(Object) }.must_raise Riffer::ArgumentError

      expect(error.message).must_include "direct subclass"
    end

    it "raises DuplicateIdentifierError against an implicit registration" do
      implicit = define_named_subclass(base, :ImplicitTool, identifier: "shared-tool")
      explicit = Class.new(base) { identifier "shared-tool" }

      error = expect { base.register(explicit) }.must_raise Riffer::DuplicateIdentifierError

      expect(error.message).must_include "shared-tool"
      expect(error.message).must_include implicit.to_s
    end

    it "raises DuplicateIdentifierError against another explicit registration" do
      first = Class.new(base) { identifier "shared-tool" }
      second = Class.new(base) { identifier "shared-tool" }
      base.register(first)

      expect { base.register(second) }.must_raise Riffer::DuplicateIdentifierError
    end

    it "raises DuplicateIdentifierError when re-registering the same class" do
      tool = Class.new(base) { identifier "shared-tool" }
      base.register(tool)

      expect { base.register(tool) }.must_raise Riffer::DuplicateIdentifierError
    end

    it "does not report a duplicate when a registered class also registers implicitly" do
      tool = Class.new(base) { identifier "overlaid-tool" }
      base.register(tool)
      RegistrableTestNamespace.const_set(:OverlaidTool, tool)

      expect(base.find("overlaid-tool")).must_equal tool
      expect(base.all).must_equal [tool]
    end

    it "raises DuplicateIdentifierError when a later subclass claims an explicit identifier" do
      explicit = Class.new(base) { identifier "shared-tool" }
      base.register(explicit)
      implicit = define_named_subclass(base, :LateTool, identifier: "shared-tool")

      error = expect { base.find("shared-tool") }.must_raise Riffer::DuplicateIdentifierError

      expect(error.message).must_include explicit.to_s
      expect(error.message).must_include implicit.to_s
    end
  end

  describe "unregister" do
    let(:base) { Class.new(Riffer::Tool) }

    it "removes an explicit registration" do
      tool = Class.new(base) { identifier "temporary-tool" }
      base.register(tool)

      base.unregister(tool)

      expect(base.find("temporary-tool")).must_be_nil
      expect(base.all).wont_include tool
    end

    it "leaves other registrations alone when the class was never registered" do
      registered = Class.new(base) { identifier "kept-tool" }
      base.register(registered)
      other = Class.new(base) { identifier "absent-tool" }

      base.unregister(other)

      expect(base.find("kept-tool")).must_equal registered
    end

    it "never removes an implicit registration" do
      tool = define_named_subclass(base, :ImplicitTool, identifier: "implicit-tool")

      base.unregister(tool)

      expect(base.find("implicit-tool")).must_equal tool
    end
  end
end
