# frozen_string_literal: true

require "test_helper"

describe Riffer::Session::Repair do
  def tool_call(call_id, name: "t", arguments: "{}")
    Riffer::Messages::Assistant::ToolCall.new(call_id: call_id, name: name, arguments: arguments)
  end

  describe ".fill_orphans" do
    after { Riffer.config.experimental_history_healing = false }

    describe "when experimental_history_healing is off" do
      let(:messages) do
        [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_orphan")])
        ]
      end

      it "returns the same array reference" do
        new_messages, _ = Riffer::Session::Repair.fill_orphans(messages)
        expect(new_messages).must_be_same_as messages
      end

      it "returns an empty filled array" do
        _, filled = Riffer::Session::Repair.fill_orphans(messages)
        expect(filled).must_equal []
      end
    end

    describe "when experimental_history_healing is on" do
      before { Riffer.config.experimental_history_healing = true }

      it "returns input unchanged when there are no orphans" do
        messages = [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_1")]),
          Riffer::Messages::Tool.new("ok", tool_call_id: "c_1", name: "t")
        ]

        new_messages, filled = Riffer::Session::Repair.fill_orphans(messages)
        expect(new_messages.length).must_equal 3
        expect(filled).must_equal []
      end

      it "inserts a placeholder Tool message immediately after the parent assistant" do
        assistant = Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_orphan")])
        messages = [Riffer::Messages::User.new("hi"), assistant]

        new_messages, _ = Riffer::Session::Repair.fill_orphans(messages)
        placeholder = new_messages[2] #: Riffer::Messages::Tool
        expect(placeholder).must_be_kind_of Riffer::Messages::Tool
        expect(placeholder.tool_call_id).must_equal "c_orphan"
      end

      it "stamps the placeholder with error_type :interrupted" do
        messages = [Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_orphan")])]

        new_messages, _ = Riffer::Session::Repair.fill_orphans(messages)
        expect(new_messages.last.error_type).must_equal :interrupted
      end

      it "uses the canned placeholder content" do
        messages = [Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_orphan")])]

        new_messages, _ = Riffer::Session::Repair.fill_orphans(messages)
        expect(new_messages.last.content).must_equal "Tool call interrupted before completion."
      end

      it "returns every filled call_id in order" do
        messages = [
          Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_a"), tool_call("c_b")])
        ]

        _, filled = Riffer::Session::Repair.fill_orphans(messages)
        expect(filled).must_equal ["c_a", "c_b"]
      end

      it "skips tool_calls that already have a matching Tool result" do
        messages = [
          Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_done"), tool_call("c_orphan")]),
          Riffer::Messages::Tool.new("ok", tool_call_id: "c_done", name: "t")
        ]

        _, filled = Riffer::Session::Repair.fill_orphans(messages)
        expect(filled).must_equal ["c_orphan"]
      end

      it "does not mutate the input array" do
        messages = [Riffer::Messages::Assistant.new("", tool_calls: [tool_call("c_orphan")])]
        original_length = messages.length

        Riffer::Session::Repair.fill_orphans(messages)
        expect(messages.length).must_equal original_length
      end
    end
  end

  describe ".prune_orphans" do
    after { Riffer.config.experimental_history_healing = false }

    describe "when experimental_history_healing is off" do
      it "returns the same array reference" do
        messages = [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Tool.new("ghost", tool_call_id: "c_missing", name: "t")
        ]

        expect(Riffer::Session::Repair.prune_orphans(messages)).must_be_same_as messages
      end
    end

    describe "when experimental_history_healing is on" do
      before { Riffer.config.experimental_history_healing = true }

      it "strips orphaned tool exchanges from non-last assistants" do
        tc = tool_call("c_drop")
        messages = [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Assistant.new("", tool_calls: [tc]),
          Riffer::Messages::User.new("anyway"),
          Riffer::Messages::Assistant.new("never mind")
        ]

        result = Riffer::Session::Repair.prune_orphans(messages)
        kept_calls = result.flat_map { |m| m.is_a?(Riffer::Messages::Assistant) ? m.tool_calls.map(&:call_id) : [] }
        expect(kept_calls).must_equal []
      end

      it "strips parentless Tool messages" do
        messages = [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Tool.new("ghost", tool_call_id: "c_missing", name: "t"),
          Riffer::Messages::User.new("follow-up")
        ]

        result = Riffer::Session::Repair.prune_orphans(messages)
        expect(result.none? { |m| m.is_a?(Riffer::Messages::Tool) }).must_equal true
      end

      it "preserves a pending tool_use on the resume boundary" do
        tc = tool_call("c_pending")
        messages = [
          Riffer::Messages::User.new("Call tool"),
          Riffer::Messages::Assistant.new("", tool_calls: [tc])
        ]

        result = Riffer::Session::Repair.prune_orphans(messages)
        kept_calls = result.flat_map { |m| m.is_a?(Riffer::Messages::Assistant) ? m.tool_calls.map(&:call_id) : [] }
        expect(kept_calls).must_equal ["c_pending"]
      end

      it "preserves completed tool exchanges on non-boundary assistants" do
        tc_done = tool_call("c_done")
        messages = [
          Riffer::Messages::User.new("hi"),
          Riffer::Messages::Assistant.new("", tool_calls: [tc_done]),
          Riffer::Messages::Tool.new("ok", tool_call_id: "c_done", name: "t"),
          Riffer::Messages::Assistant.new("all good")
        ]

        result = Riffer::Session::Repair.prune_orphans(messages)
        expect(result.length).must_equal 4
      end

      it "does not mutate the input array" do
        tc = tool_call("c_drop")
        messages = [
          Riffer::Messages::Assistant.new("", tool_calls: [tc]),
          Riffer::Messages::User.new("never mind"),
          Riffer::Messages::Assistant.new("ok")
        ]
        original_length = messages.length

        Riffer::Session::Repair.prune_orphans(messages)
        expect(messages.length).must_equal original_length
      end
    end
  end
end
