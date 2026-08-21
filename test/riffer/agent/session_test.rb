# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::Session do
  let(:user) { Riffer::Messages::User.new("hi", id: "u_1") }
  let(:plain_assistant) { Riffer::Messages::Assistant.new("hello", id: "a_1") }
  let(:tc) { Riffer::Messages::Assistant::ToolCall.new(call_id: "c_1", name: "weather", arguments: "{}") }
  let(:tool_assistant) { Riffer::Messages::Assistant.new("", id: "a_2", tool_calls: [tc]) }
  let(:tool_msg) { Riffer::Messages::Tool.new("sunny", id: "t_1", tool_call_id: "c_1", name: "weather") }

  let(:session) do
    Riffer::Agent::Session.new(messages: [user, plain_assistant, tool_assistant, tool_msg])
  end

  describe "#initialize" do
    it "defaults to an empty messages array" do
      expect(Riffer::Agent::Session.new.messages).must_equal []
    end

    it "accepts a seeded messages array" do
      expect(Riffer::Agent::Session.new(messages: [user]).messages).must_equal [user]
    end
  end

  describe "#on_message" do
    it "raises Riffer::ArgumentError when no block is given" do
      error = expect { Riffer::Agent::Session.new.on_message }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/on_message requires a block/)
    end

    it "returns self for chaining" do
      s = Riffer::Agent::Session.new

      expect(s.on_message { |_| }).must_be_same_as s
    end

    it "fires every registered callback in order on #add" do
      calls = []
      s = Riffer::Agent::Session.new
      s.on_message { |m| calls << [1, m] }
      s.on_message { |m| calls << [2, m] }
      s.add(user)

      expect(calls).must_equal [[1, user], [2, user]]
    end

    it "does not fire callbacks on #set" do
      fired = []
      s = Riffer::Agent::Session.new
      s.on_message { |m| fired << m }
      s.set([user, plain_assistant])

      expect(fired).must_equal []
    end

    it "does not fire callbacks on #unset" do
      fired = []
      s = Riffer::Agent::Session.new(messages: [plain_assistant])
      s.on_message { |m| fired << m }
      s.unset

      expect(fired).must_equal []
    end

    it "preserves registered callbacks across #set" do
      fired = []
      s = Riffer::Agent::Session.new
      s.on_message { |m| fired << m }
      s.set([user])
      s.add(plain_assistant)

      expect(fired).must_equal [plain_assistant]
    end

    it "does not fire callbacks on #update" do
      fired = []
      s = Riffer::Agent::Session.new(messages: [plain_assistant])
      s.on_message { |m| fired << m }
      s.update(id: "a_1", content: "new")

      expect(fired).must_equal []
    end

    it "does not fire callbacks on #remove" do
      fired = []
      s = Riffer::Agent::Session.new(messages: [plain_assistant])
      s.on_message { |m| fired << m }
      s.remove(id: "a_1")

      expect(fired).must_equal []
    end

    it "does not fire callbacks on #add when silent: true" do
      fired = []
      s = Riffer::Agent::Session.new
      s.on_message { |m| fired << m }
      s.add(user, silent: true)

      expect(fired).must_equal []
    end
  end

  describe "#add" do
    it "appends the message to #messages" do
      s = Riffer::Agent::Session.new
      s.add(user)

      expect(s.messages).must_equal [user]
    end

    it "returns the appended message" do
      s = Riffer::Agent::Session.new

      expect(s.add(user)).must_be_same_as user
    end

    it "still appends to #messages when silent: true" do
      s = Riffer::Agent::Session.new
      s.add(user, silent: true)

      expect(s.messages).must_equal [user]
    end
  end

  describe "#set" do
    it "replaces the messages array with the given array" do
      s = Riffer::Agent::Session.new(messages: [user])
      s.set([plain_assistant])

      expect(s.messages).must_equal [plain_assistant]
    end

    it "returns self for chaining" do
      s = Riffer::Agent::Session.new

      expect(s.set([user])).must_be_same_as s
    end
  end

  describe "#unset" do
    it "clears the session" do
      s = Riffer::Agent::Session.new(messages: [user, plain_assistant])
      s.unset

      expect(s.messages).must_equal []
    end

    it "returns self for chaining" do
      s = Riffer::Agent::Session.new(messages: [user])

      expect(s.unset).must_be_same_as s
    end
  end

  describe "#remove" do
    it "removes a plain assistant message and returns it" do
      result = session.remove(id: "a_1")

      expect(result).must_equal plain_assistant
      expect(session.find { |m| m.id == "a_1" }).must_be_nil
    end

    it "cascades to Tool children when the target carries tool_calls" do
      session.remove(id: "a_2")

      expect(session.find { |m| m.id == "a_2" }).must_be_nil
      expect(session.find { |m| m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == "c_1" }).must_be_nil
    end

    it "removes user and system messages" do
      sys_msg = Riffer::Messages::System.new("hi", id: "s_1")
      s = Riffer::Agent::Session.new(messages: [sys_msg, user])
      s.remove(id: "u_1")

      expect(s.find { |m| m.id == "u_1" }).must_be_nil
      s.remove(id: "s_1")

      expect(s.find { |m| m.id == "s_1" }).must_be_nil
    end

    it "raises Riffer::ArgumentError when called on a Tool message" do
      expect { session.remove(id: "t_1") }.must_raise Riffer::ArgumentError
    end

    it "returns nil when no message matches" do
      expect(session.remove(id: "missing")).must_be_nil
    end
  end

  describe "#update with id:" do
    it "replaces content preserving id, tool_calls, token_usage on assistant" do
      usage = Riffer::Providers::TokenUsage.new(input_tokens: 1, output_tokens: 2)
      a = Riffer::Messages::Assistant.new("old", id: "a_x", tool_calls: [tc], token_usage: usage)
      s = Riffer::Agent::Session.new(messages: [a])
      result = s.update(id: "a_x", content: "new")

      expect(result.content).must_equal "new"
      expect(result.id).must_equal "a_x"
      expect(result.tool_calls).must_equal [tc]
      expect(result.token_usage).must_be_same_as usage
    end

    it "preserves files on a user message" do
      file = Riffer::Messages::FilePart.new(media_type: "text/plain", data: "x")
      u = Riffer::Messages::User.new("old", id: "u_x", files: [file])
      s = Riffer::Agent::Session.new(messages: [u])
      result = s.update(id: "u_x", content: "new")

      expect(result.content).must_equal "new"
      expect(result.files).must_equal [file]
    end

    it "updates a system message in place" do
      sys = Riffer::Messages::System.new("old", id: "s_x")
      s = Riffer::Agent::Session.new(messages: [sys])
      result = s.update(id: "s_x", content: "new")

      expect(result.content).must_equal "new"
      expect(result.id).must_equal "s_x"
    end

    it "raises Riffer::ArgumentError on unknown id" do
      expect { session.update(id: "missing", content: "x") }.must_raise Riffer::ArgumentError
    end

    it "raises Riffer::ArgumentError when both id: and tool_call_id: are given" do
      expect { session.update(id: "a_1", tool_call_id: "c_1", content: "x") }.must_raise Riffer::ArgumentError
    end

    it "raises Riffer::ArgumentError when neither id: nor tool_call_id: is given" do
      expect { session.update(content: "x") }.must_raise Riffer::ArgumentError
    end

    it "cascades to Tool children when tool_calls is cleared" do
      session.update(id: "a_2", tool_calls: [])

      expect(session.find { |m| m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == "c_1" }).must_be_nil
    end

    it "cascades to Tool children only for dropped call_ids" do
      tc_a = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_a", name: "t", arguments: "{}")
      tc_b = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_b", name: "t", arguments: "{}")
      asst = Riffer::Messages::Assistant.new("", id: "a_x", tool_calls: [tc_a, tc_b])
      tool_a = Riffer::Messages::Tool.new("a", id: "t_a", tool_call_id: "c_a", name: "t")
      tool_b = Riffer::Messages::Tool.new("b", id: "t_b", tool_call_id: "c_b", name: "t")
      s = Riffer::Agent::Session.new(messages: [asst, tool_a, tool_b])
      s.update(id: "a_x", tool_calls: [tc_a])

      expect(s.find { |m| m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == "c_a" }).must_equal tool_a
      expect(s.find { |m| m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == "c_b" }).must_be_nil
    end
  end

  describe "#update with tool_call_id:" do
    it "replaces tool result content preserving name and id" do
      result = session.update(tool_call_id: "c_1", content: "rainy")

      expect(result.content).must_equal "rainy"
      expect(result.tool_call_id).must_equal "c_1"
      expect(result.name).must_equal "weather"
      expect(result.id).must_equal "t_1"
    end

    it "plumbs error and error_type" do
      result = session.update(tool_call_id: "c_1", content: "boom", error: "failed", error_type: :execution_error)

      expect(result.error).must_equal "failed"
      expect(result.error_type).must_equal :execution_error
      expect(result.error?).must_equal true
    end

    it "raises Riffer::ArgumentError on unknown tool_call_id" do
      expect { session.update(tool_call_id: "missing", content: "x") }.must_raise Riffer::ArgumentError
    end
  end

  describe "#orphaned_tool_call_ids" do
    it "returns [] when every tool_call has a matching tool result" do
      expect(session.orphaned_tool_call_ids).must_equal []
    end

    it "returns the unmatched call_ids" do
      tc1 = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_a", name: "t", arguments: "{}")
      tc2 = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_b", name: "t", arguments: "{}")
      asst = Riffer::Messages::Assistant.new("", id: "a_x", tool_calls: [tc1, tc2])
      result = Riffer::Messages::Tool.new("ok", id: "t_x", tool_call_id: "c_a", name: "t")
      s = Riffer::Agent::Session.new(messages: [asst, result])

      expect(s.orphaned_tool_call_ids).must_equal ["c_b"]
    end

    it "returns [] for an empty session" do
      expect(Riffer::Agent::Session.new.orphaned_tool_call_ids).must_equal []
    end
  end

  describe "#pending_tool_calls" do
    it "returns [nil, []] for an empty session" do
      expect(Riffer::Agent::Session.new.pending_tool_calls).must_equal [nil, []]
    end

    it "returns [assistant, []] when the last assistant has no tool_calls" do
      s = Riffer::Agent::Session.new(messages: [plain_assistant])
      assistant, pending = s.pending_tool_calls

      expect(assistant).must_equal plain_assistant
      expect(pending).must_equal []
    end

    it "returns [assistant, []] when every tool_call has a matching result" do
      assistant, pending = session.pending_tool_calls

      expect(assistant).must_equal tool_assistant
      expect(pending).must_equal []
    end

    it "returns [assistant, pending] when some calls are unanswered" do
      tc1 = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_a", name: "t", arguments: "{}")
      tc2 = Riffer::Messages::Assistant::ToolCall.new(call_id: "c_b", name: "t", arguments: "{}")
      asst = Riffer::Messages::Assistant.new("", id: "a_x", tool_calls: [tc1, tc2])
      result = Riffer::Messages::Tool.new("ok", id: "t_x", tool_call_id: "c_a", name: "t")
      s = Riffer::Agent::Session.new(messages: [asst, result])
      assistant, pending = s.pending_tool_calls

      expect(assistant).must_equal asst
      expect(pending.map(&:call_id)).must_equal ["c_b"]
    end
  end

  describe "Enumerable" do
    it "yields each message via #each" do
      collected = session.to_a

      expect(collected).must_equal [user, plain_assistant, tool_assistant, tool_msg]
    end

    it "supports #find" do
      expect(session.find { |m| m.id == "a_1" }).must_equal plain_assistant
    end

    it "supports #count with a block" do
      expect(session.count { |m| m.is_a?(Riffer::Messages::Assistant) }).must_equal 2
    end

    it "supports #reverse_each" do
      # TODO: Replace with rfind when minimum Ruby is 4.0+
      first_assistant_from_end = session.reverse_each.find { |m| m.is_a?(Riffer::Messages::Assistant) }

      expect(first_assistant_from_end).must_equal tool_assistant
    end

    it "returns an Enumerator when #each is called without a block" do
      expect(session.each).must_be_kind_of Enumerator
    end
  end

  describe "#steps" do
    it "is zero when there are no assistant messages" do
      s = Riffer::Agent::Session.new(messages: [user])

      expect(s.steps).must_equal 0
    end

    it "counts assistant messages only" do
      s = Riffer::Agent::Session.new(messages: [user, plain_assistant, tool_msg, tool_assistant])

      expect(s.steps).must_equal 2
    end
  end

  describe "#final_assistant_message" do
    it "returns nil when there are no assistant messages" do
      s = Riffer::Agent::Session.new(messages: [user])

      expect(s.final_assistant_message).must_be_nil
    end

    it "returns the most recent assistant message" do
      s = Riffer::Agent::Session.new(messages: [user, plain_assistant, user, tool_assistant])

      expect(s.final_assistant_message).must_equal tool_assistant
    end

    it "ignores trailing non-assistant messages" do
      s = Riffer::Agent::Session.new(messages: [user, plain_assistant, tool_msg])

      expect(s.final_assistant_message).must_equal plain_assistant
    end
  end
end
