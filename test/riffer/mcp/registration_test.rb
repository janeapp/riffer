# frozen_string_literal: true

require "test_helper"

describe Riffer::Mcp::Registration do
  let(:manifest) do
    Riffer::Mcp::Manifest.new(name: "test-srv", tags: [:test], endpoint: "https://test.example.com")
  end

  # Build a registration whose discovery thread is bypassed so tests control state directly.
  def build_stub_registration(manifest, ready: false, tools: [])
    reg = Riffer::Mcp::Registration.allocate
    reg.instance_variable_set(:@manifest, manifest)
    reg.instance_variable_set(:@ready, ready)
    reg.instance_variable_set(:@cancelled, false)
    reg.instance_variable_set(:@tools, tools)
    reg.instance_variable_set(:@discovery_thread, nil)
    reg.instance_variable_set(:@mutex, Mutex.new)
    reg
  end

  # A Registration subclass that injects a fake MCP client, bypassing real HTTP.
  def build_injected_registration(manifest, client:)
    klass = Class.new(Riffer::Mcp::Registration) do
      attr_writer :injected_client

      private

      def build_client
        @injected_client
      end
    end
    reg = klass.new(manifest)
    reg.injected_client = client
    reg
  end

  describe "#manifest" do
    it "returns the manifest" do
      reg = build_stub_registration(manifest)
      assert_equal manifest, reg.manifest
    end
  end

  describe "#ready?" do
    it "returns false before discovery completes" do
      reg = build_stub_registration(manifest, ready: false)
      refute reg.ready?
    end

    it "returns true after discovery completes" do
      reg = build_stub_registration(manifest, ready: true)
      assert reg.ready?
    end
  end

  describe "#tools" do
    it "returns empty array before discovery" do
      reg = build_stub_registration(manifest)
      assert_empty reg.tools
    end

    it "returns tool classes after discovery" do
      tool_class = Class.new(Riffer::Tool)
      reg = build_stub_registration(manifest, ready: true, tools: [tool_class])
      assert_equal [tool_class], reg.tools
    end
  end

  describe "#wait_until_ready!" do
    it "returns immediately when already ready" do
      reg = build_stub_registration(manifest, ready: true)
      assert_nil reg.wait_until_ready!
    end

    it "re-raises discovery_error immediately when discovery failed" do
      reg = build_stub_registration(manifest, ready: false)
      reg.instance_variable_set(:@discovery_error, RuntimeError.new("discovery failed"))
      err = assert_raises(RuntimeError) { reg.wait_until_ready! }
      assert_equal "discovery failed", err.message
    end

    it "raises TimeoutError when deadline passes without becoming ready" do
      reg = build_stub_registration(manifest, ready: false)
      original_timeout = Riffer.config.mcp.wait_timeout
      Riffer.config.mcp.wait_timeout = 0.05
      assert_raises(Riffer::Mcp::TimeoutError) { reg.wait_until_ready! }
    ensure
      Riffer.config.mcp.wait_timeout = original_timeout
    end

    it "returns once the ready flag is set by another thread" do
      reg = build_stub_registration(manifest, ready: false)
      original_timeout = Riffer.config.mcp.wait_timeout
      Riffer.config.mcp.wait_timeout = 1

      Thread.new do
        sleep 0.1
        reg.instance_variable_get(:@mutex).synchronize do
          reg.instance_variable_set(:@ready, true)
        end
      end

      assert_nil reg.wait_until_ready!
    ensure
      Riffer.config.mcp.wait_timeout = original_timeout
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

    it "prevents a completing discovery thread from publishing state" do
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
      reg.instance_variable_set(:@ready, false)
      reg.instance_variable_set(:@cancelled, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@discovery_error, nil)
      reg.instance_variable_set(:@discovery_thread, nil)
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.latch = latch

      thread = reg.send(:spawn_discovery_thread)
      reg.retire!
      latch.unlock
      thread.join

      refute reg.ready?
      assert_empty reg.tools
    end
  end

  describe "configurable discovery_thread_factory" do
    it "uses the configured factory instead of Thread.new" do
      original_factory = Riffer.config.mcp.discovery_thread_factory
      factory_called = false

      Riffer.config.mcp.discovery_thread_factory = ->(&block) {
        factory_called = true
        Thread.new(&block)
      }

      fake_client = Object.new
      fake_client.define_singleton_method(:tools_list) { [] }

      klass = Class.new(Riffer::Mcp::Registration) do
        attr_writer :injected_client

        private

        def build_client = @injected_client
      end

      reg = klass.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@ready, false)
      reg.instance_variable_set(:@cancelled, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@discovery_error, nil)
      reg.instance_variable_set(:@discovery_thread, nil)
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.injected_client = fake_client
      reg.send(:spawn_discovery_thread).join

      assert factory_called, "expected discovery_thread_factory to be called"
    ensure
      Riffer.config.mcp.discovery_thread_factory = original_factory
    end
  end

  describe "discovery thread" do
    it "sets ready=true and populates tools when discovery succeeds" do
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
      reg.instance_variable_set(:@ready, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.injected_client = fake_client
      reg.send(:spawn_discovery_thread).join

      assert reg.ready?
      assert_equal 1, reg.tools.size
      assert_equal "ping", reg.tools.first.name
    end

    it "leaves ready=false when discovery raises" do
      bad_client = Object.new
      bad_client.define_singleton_method(:tools_list) { raise "connection refused" }

      klass = Class.new(Riffer::Mcp::Registration) do
        attr_writer :injected_client

        private

        def build_client = @injected_client
      end

      reg = klass.allocate
      reg.instance_variable_set(:@manifest, manifest)
      reg.instance_variable_set(:@ready, false)
      reg.instance_variable_set(:@tools, [])
      reg.instance_variable_set(:@discovery_error, nil)
      reg.instance_variable_set(:@mutex, Mutex.new)
      reg.injected_client = bad_client
      reg.send(:spawn_discovery_thread).join

      refute reg.ready?
      assert_instance_of RuntimeError, reg.discovery_error
      assert_equal "connection refused", reg.discovery_error.message
      err = assert_raises(RuntimeError) { reg.wait_until_ready! }
      assert_equal "connection refused", err.message
    end
  end
end
