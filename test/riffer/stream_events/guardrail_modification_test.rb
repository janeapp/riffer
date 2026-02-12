# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::GuardrailModification do
  let(:modification) do
    Riffer::Guardrails::Modification.new(
      guardrail: Riffer::Guardrail,
      phase: :before,
      message_indices: [0, 1]
    )
  end

  describe "#modification" do
    it "returns the modification record" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.modification).must_equal modification
    end
  end

  describe "#guardrail" do
    it "delegates to modification" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.guardrail).must_equal Riffer::Guardrail
    end
  end

  describe "#phase" do
    it "delegates to modification" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.phase).must_equal :before
    end
  end

  describe "#message_indices" do
    it "delegates to modification" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.message_indices).must_equal [0, 1]
    end
  end

  describe "#role" do
    it "defaults to assistant" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.role).must_equal :assistant
    end

    it "accepts custom role" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification, role: :system)
      expect(event.role).must_equal :system
    end
  end

  describe "#to_h" do
    it "includes role" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.to_h[:role]).must_equal :assistant
    end

    it "includes modification hash" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.to_h[:modification][:guardrail]).must_be_kind_of String
      expect(event.to_h[:modification][:guardrail]).wont_be_empty
    end

    it "includes phase in modification hash" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.to_h[:modification][:phase]).must_equal :before
    end

    it "includes message_indices in modification hash" do
      event = Riffer::StreamEvents::GuardrailModification.new(modification)
      expect(event.to_h[:modification][:message_indices]).must_equal [0, 1]
    end
  end
end
