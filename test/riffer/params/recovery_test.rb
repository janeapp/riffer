# frozen_string_literal: true

require "test_helper"

describe Riffer::Params::Recovery do
  def array_param(of: nil, &block)
    params = Riffer::Params.new
    params.required(:rows, Array, of: of, &block)
    params.parameters.first
  end

  def recover(param, value)
    Riffer::Params::Recovery.call(param, value)
  end

  describe ".call" do
    it "decodes an array param the model wrote as a JSON string" do
      param = array_param { required :label, String }

      expect(recover(param, '[{"label":"a"}]')).must_equal([{ label: "a" }])
    end

    it "symbolizes decoded keys, so nested validation sees the fields" do
      param = array_param { required :label, String }

      expect(recover(param, '[{"label":"a"}]').first.keys).must_equal([:label])
    end

    it "decodes an of:-typed array param too" do
      param = array_param(of: Integer)

      expect(recover(param, "[1,2]")).must_equal([1, 2])
    end

    it "leaves a value that decodes to an object alone" do
      param = array_param { required :label, String }

      expect(recover(param, '{"label":"a"}')).must_equal('{"label":"a"}')
    end

    it "leaves prose alone" do
      param = array_param { required :label, String }

      expect(recover(param, "I updated the note.")).must_equal("I updated the note.")
    end

    it "leaves a truncated payload alone rather than raising" do
      param = array_param { required :label, String }

      expect(recover(param, '[{"label":')).must_equal('[{"label":')
    end

    it "leaves an already-valid array alone" do
      param = array_param { required :label, String }

      expect(recover(param, [{ label: "a" }])).must_equal([{ label: "a" }])
    end

    it "leaves a non-Array param alone" do
      params = Riffer::Params.new
      params.required(:city, String)

      expect(recover(params.parameters.first, "[1,2]")).must_equal("[1,2]")
    end
  end
end
