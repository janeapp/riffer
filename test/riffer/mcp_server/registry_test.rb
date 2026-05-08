# frozen_string_literal: true

require "test_helper"

describe Riffer::McpServer::Registry do
  let(:registry) { Riffer::McpServer::Registry.new }

  let(:tool_a) do
    Class.new(Riffer::Tool) do
      identifier "tool_a"
      description "Tool A"
    end
  end

  let(:tool_b) do
    Class.new(Riffer::Tool) do
      identifier "tool_b"
      description "Tool B"
    end
  end

  describe "#register and #lookup" do
    it "stores a registration and finds it by tool name" do
      registry.register(tool_a)
      record = registry.lookup("tool_a")
      assert_equal tool_a, record[:tool_class]
      assert_equal :default, record[:scope]
    end

    it "returns nil for an unknown tool name" do
      assert_nil registry.lookup("missing")
    end

    it "defaults the scope to :default when not given" do
      registry.register(tool_a)
      assert_equal :default, registry.lookup("tool_a")[:scope]
    end

    it "accepts a custom Symbol scope" do
      registry.register(tool_a, scope: :admin)
      assert_equal :admin, registry.lookup("tool_a")[:scope]
    end

    it "accepts an Array<Symbol> scope" do
      registry.register(tool_a, scope: [:admin, :default])
      assert_equal [:admin, :default], registry.lookup("tool_a")[:scope]
    end

    it "keeps both records when re-registering, with lookup returning the most recent" do
      registry.register(tool_a, scope: :first)
      registry.register(tool_a, scope: :second)
      assert_equal :second, registry.lookup("tool_a")[:scope]
      assert_equal 2, registry.all.size
    end
  end

  describe "#all_for_scope" do
    it "returns records whose scope is the given Symbol" do
      registry.register(tool_a, scope: :admin)
      registry.register(tool_b, scope: :default)
      results = registry.all_for_scope(:admin)
      assert_equal 1, results.size
      assert_equal tool_a, results.first[:tool_class]
    end

    it "returns records whose Array<Symbol> scope includes the given Symbol" do
      registry.register(tool_a, scope: [:admin, :default])
      results = registry.all_for_scope(:default)
      assert_equal 1, results.size
      assert_equal tool_a, results.first[:tool_class]
    end

    it "returns empty when no record matches the scope" do
      registry.register(tool_a, scope: :admin)
      assert_empty registry.all_for_scope(:nope)
    end

    it "returns empty when the queried Symbol is not in any Array<Symbol> scope" do
      registry.register(tool_a, scope: [:admin, :default])
      assert_empty registry.all_for_scope(:nope)
    end
  end

  describe "#all" do
    it "returns a frozen snapshot of all records" do
      registry.register(tool_a)
      snapshot = registry.all
      assert snapshot.frozen?
      assert_equal 1, snapshot.size
    end

    it "returns an independent snapshot — mutating it doesn't affect the registry" do
      registry.register(tool_a)
      snapshot = registry.all
      assert_raises(FrozenError) { snapshot << {tool_class: tool_b, scope: :default} }
      assert_equal 1, registry.all.size
    end
  end

  describe "#clear!" do
    it "removes all registrations" do
      registry.register(tool_a)
      registry.register(tool_b)
      registry.clear!
      assert_empty registry.all
    end
  end

  describe "thread safety" do
    it "supports concurrent registration without losing records" do
      tool_classes = 50.times.map do |i|
        Class.new(Riffer::Tool) do
          identifier "tool_#{i}"
          description "Tool #{i}"
        end
      end

      threads = tool_classes.map do |klass|
        Thread.new { registry.register(klass) }
      end
      threads.each(&:join)

      assert_equal 50, registry.all.size
    end
  end
end
