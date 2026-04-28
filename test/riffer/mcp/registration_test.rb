# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::Registration do
  let(:manifest) do
    Riffer::Mcp::Manifest.new(name: "test-srv", tags: [:test], endpoint: "https://test.example.com")
  end

  # Build a registration whose discovery is bypassed so tests control state directly.
  def build_stub_registration(manifest, tools: [])
    reg = Riffer::Mcp::Registration.allocate
    reg.instance_variable_set(:@manifest, manifest)
    reg.instance_variable_set(:@cancelled, false)
    reg.instance_variable_set(:@tools, tools)
    reg.instance_variable_set(:@mutex, Mutex.new)
    reg
  end

  describe "#manifest" do
    it "returns the manifest" do
      reg = build_stub_registration(manifest)
      assert_equal manifest, reg.manifest
    end
  end

  describe "#tools" do
    it "returns empty array before discovery" do
      reg = build_stub_registration(manifest)
      assert_empty reg.tools
    end

    it "returns tool classes after discovery" do
      tool_class = Class.new(Riffer::Tool)
      reg = build_stub_registration(manifest, tools: [tool_class])
      assert_equal [tool_class], reg.tools
    end
  end

  describe "#retired?" do
    it "returns false initially" do
      reg = build_stub_registration(manifest)
      refute reg.retired?
    end

    it "returns true after retire!" do
      reg = build_stub_registration(manifest)
      reg.retire!
      assert reg.retired?
    end
  end

  describe "#retire!" do
    it "sets the cancelled flag" do
      reg = build_stub_registration(manifest)
      reg.retire!
      assert reg.retired?
    end

    it "prevents in-flight discovery from publishing state" do
      latch = Mutex.new
      latch.lock

      klass = Class.new(Riffer::Mcp::Registration) do
        attr_writer :latch

        private

        def build_client
          client = Object.new
          l = @latch
          client.define_singleton_method(:tools_list) {
            l.lock
            l.unlock
            []
          }
          client
        end
      end

      reg = klass.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@cancelled, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.latch = latch

      thread = Thread.new { reg.send(:run_discovery) }
      sleep 0.01
      reg.retire!
      latch.unlock
      thread.join

      assert_empty reg.tools
    end
  end

  describe "configurable discovery_runner" do
    it "uses the configured runner instead of the default" do
      original_runner = Riffer.config.mcp.discovery_runner
      runner_called = false

      custom_runner = Object.new
      custom_runner.define_singleton_method(:map) do |items, context:, &block|
        runner_called = true
        items.map(&block)
      end

      Riffer.config.mcp.discovery_runner = custom_runner

      fake_client = Object.new
      fake_client.define_singleton_method(:tools_list) { [] }

      klass = Class.new(Riffer::Mcp::Registration) do
        attr_writer :injected_client

        private

        def build_client = @injected_client
      end

      reg = klass.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@cancelled, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.injected_client = fake_client
      reg.send(:run_discovery)

      assert runner_called, "expected discovery_runner to be called"
    ensure
      Riffer.config.mcp.discovery_runner = original_runner
    end
  end

  describe "discovery" do
    it "populates tools when discovery succeeds" do
      td = {name: "ping", description: "Ping", input_schema: {type: "object", properties: {}, required: [], additionalProperties: false}}
      fake_client = Object.new
      fake_client.define_singleton_method(:tools_list) { [td] }

      klass = Class.new(Riffer::Mcp::Registration) do
        attr_writer :injected_client

        private

        def build_client = @injected_client
      end

      reg = klass.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@cancelled, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.injected_client = fake_client
      reg.send(:run_discovery)

      assert_equal 1, reg.tools.size
      assert_equal "ping", reg.tools.first.name
    end

    it "raises when discovery fails" do
      bad_client = Object.new
      bad_client.define_singleton_method(:tools_list) { raise "connection refused" }

      klass = Class.new(Riffer::Mcp::Registration) do
        attr_writer :injected_client

        private

        def build_client = @injected_client
      end

      reg = klass.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@cancelled, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.injected_client = bad_client

      err = assert_raises(RuntimeError) { reg.send(:run_discovery) }
      assert_equal "connection refused", err.message
    end
  end
end
